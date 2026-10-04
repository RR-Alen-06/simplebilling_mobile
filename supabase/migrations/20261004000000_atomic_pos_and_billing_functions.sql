-- Migration: 20261004000000_atomic_pos_and_billing_functions.sql
-- Description: Atomic PostgreSQL functions and RPC handlers for SimpleBilling POS & Credit Ledger

-- 1. Atomic Sequence Generator
CREATE OR REPLACE FUNCTION public.get_next_sequence(p_key TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_prefix TEXT;
    v_padding INT;
    v_next_val BIGINT;
    v_result TEXT;
BEGIN
    -- Upsert sequence record and lock row
    INSERT INTO public.sequences (key, prefix, padding, current_val, updated_at)
    VALUES (UPPER(p_key), UPPER(SUBSTRING(p_key FROM 1 FOR 3)), 6, 1, NOW())
    ON CONFLICT (key) DO UPDATE
    SET current_val = sequences.current_val + 1,
        updated_at = NOW()
    RETURNING prefix, padding, current_val INTO v_prefix, v_padding, v_next_val;

    v_result := v_prefix || '-' || LPAD(v_next_val::TEXT, v_padding, '0');
    RETURN v_result;
END;
$$;

-- 2. Atomic Bill Creation with FIFO Overpayment Settlement & Loyalty
CREATE OR REPLACE FUNCTION public.create_bill_atomic(
    p_bill JSONB,
    p_items JSONB,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_bill_id UUID;
    v_customer_id UUID;
    v_bill_number TEXT;
    v_grand_total NUMERIC;
    v_cash_paid NUMERIC;
    v_upi_paid NUMERIC;
    v_card_paid NUMERIC;
    v_direct_paid NUMERIC;
    v_advance_used NUMERIC;
    v_net_due NUMERIC;
    v_overpayment NUMERIC;
    v_prior_due NUMERIC;
    v_allocated_to_prior NUMERIC := 0;
    v_effective_advance_earned NUMERIC := 0;
    v_effective_paid_total NUMERIC;
    v_is_fully_paid BOOLEAN;
    v_points_earned NUMERIC;
    v_points_redeemed NUMERIC;
    v_rec RECORD;
    v_alloc NUMERIC;
    v_new_paid NUMERIC;
    v_pnum TEXT;
    v_item RECORD;
    v_cur_advance NUMERIC;
    v_cur_loyalty NUMERIC;
BEGIN
    v_user_id := COALESCE(p_user_id, auth.uid());
    v_bill_number := p_bill->>'bill_number';
    v_customer_id := (p_bill->>'customer_id')::UUID;
    v_grand_total := (p_bill->>'grand_total')::NUMERIC;
    v_cash_paid := COALESCE((p_bill->>'cash_paid')::NUMERIC, 0);
    v_upi_paid := COALESCE((p_bill->>'upi_paid')::NUMERIC, 0);
    v_card_paid := COALESCE((p_bill->>'card_paid')::NUMERIC, 0);
    v_advance_used := COALESCE((p_bill->>'advance_used')::NUMERIC, 0);
    v_points_redeemed := COALESCE((p_bill->>'loyalty_points_redeemed')::NUMERIC, 0);
    v_points_earned := COALESCE((p_bill->>'loyalty_points_earned')::NUMERIC, 0);

    v_direct_paid := v_cash_paid + v_upi_paid + v_card_paid;
    v_net_due := GREATEST(0, v_grand_total - v_advance_used);
    v_overpayment := GREATEST(0, v_direct_paid - v_net_due);

    -- Calculate Prior Bills Outstanding for Customer
    IF v_customer_id IS NOT NULL AND v_overpayment > 0 THEN
        FOR v_rec IN 
            SELECT id, grand_total, paid_total, loyalty_points_earned 
            FROM public.bills 
            WHERE customer_id = v_customer_id 
              AND paid_total < grand_total
            ORDER BY created_at ASC
        LOOP
            v_prior_due := v_rec.grand_total - v_rec.paid_total;
            IF v_overpayment > v_allocated_to_prior THEN
                v_alloc := LEAST(v_overpayment - v_allocated_to_prior, v_prior_due);
                v_allocated_to_prior := v_allocated_to_prior + v_alloc;
                v_new_paid := v_rec.paid_total + v_alloc;

                -- Update prior bill paid total
                UPDATE public.bills SET paid_total = v_new_paid WHERE id = v_rec.id;

                -- Generate sequence and insert payment record
                v_pnum := public.get_next_sequence('PAYMENT');
                INSERT INTO public.payments (
                    payment_number, customer_id, bill_id, amount, payment_method, notes, user_id, created_at
                ) VALUES (
                    v_pnum, v_customer_id, v_rec.id, v_alloc, 
                    CASE WHEN v_upi_paid > v_cash_paid THEN 'UPI' ELSE 'Cash' END,
                    'Automated FIFO allocation from Bill #' || v_bill_number,
                    v_user_id, NOW()
                );
            END IF;
        END LOOP;
    END IF;

    v_effective_advance_earned := CASE WHEN v_customer_id IS NOT NULL THEN (v_overpayment - v_allocated_to_prior) ELSE 0 END;
    v_effective_paid_total := LEAST(v_grand_total, v_direct_paid + v_advance_used);
    v_is_fully_paid := (v_effective_paid_total >= v_grand_total - 0.01);
    IF NOT v_is_fully_paid THEN
        v_points_earned := 0;
    END IF;

    -- Insert Primary Bill Record
    INSERT INTO public.bills (
        bill_number, customer_id, total, discount, gst_amount, rounding_method,
        rounding_adjustment, grand_total, cash_paid, upi_paid, card_paid,
        paid_total, advance_used, advance_earned, payment_method,
        loyalty_points_earned, loyalty_points_redeemed, user_id, created_at
    ) VALUES (
        v_bill_number,
        v_customer_id,
        (p_bill->>'total')::NUMERIC,
        COALESCE((p_bill->>'discount')::NUMERIC, 0),
        COALESCE((p_bill->>'gst_amount')::NUMERIC, 0),
        p_bill->>'rounding_method',
        COALESCE((p_bill->>'rounding_adjustment')::NUMERIC, 0),
        v_grand_total,
        v_cash_paid,
        v_upi_paid,
        v_card_paid,
        v_effective_paid_total,
        v_advance_used,
        v_effective_advance_earned,
        p_bill->>'payment_method',
        v_points_earned,
        v_points_redeemed,
        v_user_id,
        NOW()
    ) RETURNING id INTO v_bill_id;

    -- Insert Bill Items
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
        product_id UUID, product_name TEXT, quantity NUMERIC, price NUMERIC, total NUMERIC
    )
    LOOP
        INSERT INTO public.bill_items (
            bill_id, product_id, product_name, quantity, price, total
        ) VALUES (
            v_bill_id, v_item.product_id, v_item.product_name, v_item.quantity, v_item.price, v_item.total
        );
    END LOOP;

    -- Direct payments for current bill
    IF (v_cash_paid - v_allocated_to_prior) > 0 THEN
        v_pnum := public.get_next_sequence('PAYMENT');
        INSERT INTO public.payments (
            payment_number, customer_id, bill_id, amount, payment_method, notes, user_id, created_at
        ) VALUES (
            v_pnum, v_customer_id, v_bill_id, (v_cash_paid - v_allocated_to_prior), 'Cash',
            'POS Cash payment for ' || v_bill_number, v_user_id, NOW()
        );
    END IF;

    IF v_upi_paid > 0 THEN
        v_pnum := public.get_next_sequence('PAYMENT');
        INSERT INTO public.payments (
            payment_number, customer_id, bill_id, amount, payment_method, notes, user_id, created_at
        ) VALUES (
            v_pnum, v_customer_id, v_bill_id, v_upi_paid, 'UPI',
            'POS UPI payment for ' || v_bill_number, v_user_id, NOW()
        );
    END IF;

    -- Update Customer Advance & Loyalty Balances
    IF v_customer_id IS NOT NULL THEN
        SELECT advance_balance, loyalty_points INTO v_cur_advance, v_cur_loyalty
        FROM public.customers WHERE id = v_customer_id FOR UPDATE;

        UPDATE public.customers SET
            advance_balance = GREATEST(0, COALESCE(v_cur_advance, 0) - v_advance_used + v_effective_advance_earned),
            loyalty_points = GREATEST(0, COALESCE(v_cur_loyalty, 0) - v_points_redeemed + v_points_earned)
        WHERE id = v_customer_id;

        -- Record Loyalty Transactions
        IF v_points_earned > 0 THEN
            INSERT INTO public.loyalty_transactions (
                transaction_number, customer_id, bill_id, points, type, notes, user_id, created_at
            ) VALUES (
                public.get_next_sequence('LOYALTY'), v_customer_id, v_bill_id, v_points_earned, 'EARN',
                'Award Reason: Bill Fully Paid - ' || v_bill_number, v_user_id, NOW()
            );
        END IF;

        IF v_points_redeemed > 0 THEN
            INSERT INTO public.loyalty_transactions (
                transaction_number, customer_id, bill_id, points, type, notes, user_id, created_at
            ) VALUES (
                public.get_next_sequence('LOYALTY'), v_customer_id, v_bill_id, v_points_redeemed, 'REDEEM',
                'Loyalty points redeemed on bill ' || v_bill_number, v_user_id, NOW()
            );
        END IF;
    END IF;

    -- Audit Log
    INSERT INTO public.audit_logs (audit_number, action, entity, new_value, user_id, created_at)
    VALUES (
        public.get_next_sequence('AUDIT'), 'CREATE_BILL', v_bill_number,
        'Grand Total: ₹' || v_grand_total || ' (' || (p_bill->>'payment_method') || ')',
        v_user_id, NOW()
    );

    RETURN jsonb_build_object('id', v_bill_id, 'bill_number', v_bill_number);
END;
$$;

-- 3. Atomic Customer Payment Recording with FIFO Settlement
CREATE OR REPLACE FUNCTION public.record_customer_payment_atomic(
    p_payment_number TEXT,
    p_customer_id UUID,
    p_amount NUMERIC,
    p_payment_method TEXT,
    p_notes TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_remaining_payment NUMERIC := p_amount;
    v_unlocked_loyalty NUMERIC := 0;
    v_rec RECORD;
    v_due NUMERIC;
    v_alloc NUMERIC;
    v_new_paid NUMERIC;
    v_cur_advance NUMERIC;
    v_cur_loyalty NUMERIC;
    v_updated_advance NUMERIC;
    v_updated_loyalty NUMERIC;
BEGIN
    v_user_id := COALESCE(p_user_id, auth.uid());

    -- 1. Insert Payment Record
    INSERT INTO public.payments (
        payment_number, customer_id, amount, payment_method, notes, user_id, created_at
    ) VALUES (
        p_payment_number, p_customer_id, p_amount, p_payment_method,
        COALESCE(p_notes, 'Credit settlement collection'), v_user_id, NOW()
    );

    -- 2. Allocate payment to unpaid bills in chronological order
    FOR v_rec IN 
        SELECT id, grand_total, paid_total, loyalty_points_earned, bill_number
        FROM public.bills 
        WHERE customer_id = p_customer_id AND paid_total < grand_total
        ORDER BY created_at ASC
        FOR UPDATE
    LOOP
        EXIT WHEN v_remaining_payment <= 0;

        v_due := v_rec.grand_total - v_rec.paid_total;
        v_alloc := LEAST(v_remaining_payment, v_due);
        v_new_paid := v_rec.paid_total + v_alloc;

        UPDATE public.bills SET paid_total = v_new_paid WHERE id = v_rec.id;

        -- If bill cleared, unlock deferred loyalty points
        IF v_new_paid >= v_rec.grand_total - 0.01 AND v_rec.loyalty_points_earned > 0 THEN
            v_unlocked_loyalty := v_unlocked_loyalty + v_rec.loyalty_points_earned;
            
            INSERT INTO public.loyalty_transactions (
                transaction_number, customer_id, bill_id, points, type, notes, user_id, created_at
            ) VALUES (
                public.get_next_sequence('LOYALTY'), p_customer_id, v_rec.id, v_rec.loyalty_points_earned,
                'EARN', 'Award Reason: Bill Cleared via Settlement #' || p_payment_number, v_user_id, NOW()
            );
        END IF;

        v_remaining_payment := v_remaining_payment - v_alloc;
    END LOOP;

    -- 3. Update Customer advance balance and loyalty points
    SELECT advance_balance, loyalty_points INTO v_cur_advance, v_cur_loyalty
    FROM public.customers WHERE id = p_customer_id FOR UPDATE;

    v_updated_advance := COALESCE(v_cur_advance, 0) + v_remaining_payment;
    v_updated_loyalty := COALESCE(v_cur_loyalty, 0) + v_unlocked_loyalty;

    UPDATE public.customers SET
        advance_balance = v_updated_advance,
        loyalty_points = v_updated_loyalty
    WHERE id = p_customer_id;

    -- 4. Audit Log
    INSERT INTO public.audit_logs (audit_number, action, entity, new_value, user_id, created_at)
    VALUES (
        public.get_next_sequence('AUDIT'), 'RECORD_CUSTOMER_PAYMENT',
        'Customer ' || p_customer_id::TEXT || ' (' || p_payment_number || ')',
        'Amount: ₹' || p_amount || ' (' || p_payment_method || '), Advance: ₹' || v_updated_advance || ', Loyalty +' || v_unlocked_loyalty,
        v_user_id, NOW()
    );

    RETURN jsonb_build_object(
        'payment_number', p_payment_number,
        'advance_balance', v_updated_advance,
        'loyalty_points', v_updated_loyalty,
        'unlocked_loyalty', v_unlocked_loyalty
    );
END;
$$;
