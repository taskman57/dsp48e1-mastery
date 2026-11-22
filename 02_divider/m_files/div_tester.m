function div_tester(wn, wd, frc)
    clc;
    printf(" Restoring division loop testing\n\r");
    for i = 1:wn
        for j = 1:wd
            for k = 0:frc
                [q_int, r, r_int] = div_restoring(int64(2^i), int64(2^j-1), k);
                m_q = idivide(int64(2^(i+k)), int64(2^j-1), "fix");
                m_rint = rem(2^i,2^j-1);
                if m_q != q_int || m_rint != r_int
                    printf(" Incorrect quotient and remainder. \n\r");
                    printf(" wn=%d, wd=%d, frc=%d. q: %d, r_int: %d \n\r", i, j, k, q_int, r_int);
                    printf(" q: %d r_int: %d \n\r", m_q, m_rint);
                else
                    printf(" Restoring division worked for wn=%d, wd=%d frc=%d \n\r", i, j, k);
                endif
            endfor
        endfor
    endfor
    printf(" Nonrestoring division loop testing\n\r");
    for i = 1:wn
        for j = 1:wd
            for k = 0:frc
                [q_int, r, r_int] = div_nonrestoring(int64(2^i), int64(2^j-1), k);
                m_q = idivide(int64(2^(i+k)), int64(2^j-1), "fix");
                m_rint = rem(2^i,2^j-1);
                if m_q != q_int || m_rint != r_int
                    printf(" Incorrect quotient and remainder. \n\r");
                    printf(" wn=%d, wd=%d, frc=%d. q: %d, r_int: %d \n\r", i, j, k, q_int, r_int);
                    printf(" q: %d r_int: %d \n\r", m_q, m_rint);
                else
                    printf(" Nonrestoring division worked for wn=%d, wd=%d frc=%d\n\r", i, j, k);
                endif
            endfor
        endfor
    endfor

    %%%%%%      Random number testing       %%%%%%%%%
    printf(" Random number testing, Nonrestoring division\n\r");
    div_result = 0;
    for i = 1: 1000
        dividend = int64(randi(2^52));
        divisor = int64(randi(2^32));

        [q_int, r, r_int] = div_nonrestoring(dividend, divisor, frc);
        m_q = idivide(int64(dividend*2^frc), int64(divisor), "fix");
        m_rint = rem(dividend,divisor);
        if m_q != q_int || m_rint != r_int
            printf(" Incorrect quotient and remainder. \n\r");
            printf(" dividend= %d, divisor= %d, q: %d, r_int: %d \n\r", dividend, divisor, q_int, r_int);
            printf(" q: %d r_int: %d \n\r", m_q, m_rint);
            div_result = -1;
            break;
        endif
    endfor
    if div_result == 0
        printf(" Nonrestoring division worked for random division. \n\r");
    else
        printf(" Nonrestoring division of random testing failed with dividend: %d and division: %d. \n\r", dividend, divisor);
    endif

    printf(" Random number testing, Restoring division\n\r");
    div_result = 0;
    for i = 1: 1000
        dividend = int64(randi(2^52));
        divisor = int64(randi(2^32));

        [q_int, r, r_int] = div_restoring(dividend, divisor, frc);
        m_q = idivide(int64(dividend*2^frc), int64(divisor), "fix");
        m_rint = rem(dividend,divisor);
        if m_q != q_int || m_rint != r_int
            printf(" Incorrect quotient and remainder. \n\r");
            printf(" dividend= %d, divisor= %d, q: %d, r_int: %d \n\r", dividend, divisor, q_int, r_int);
            printf(" q: %d r_int: %d \n\r", m_q, m_rint);
            div_result = -1;
            break;
        endif
    endfor
    if div_result == 0
        printf(" Restoring division worked for random division. \n\r");
    else
        printf(" Restoring division of random testing failed with dividend: %d and division: %d. \n\r", dividend, divisor);
    endif

    %%%%%%%%        corner case testing         %%%%%%%%%%%
    %%%%%%%%        Zero dividend testing      %%%%%%%%%%%
    printf(" Corner case division testing. \n\r");
    printf(" Zero dividend Restoring division. \n\r");
    % zero dividend
    dividend = 0;
    divisor = 1;

    [q_int, r, r_int] = div_restoring(dividend, divisor, frc);
    m_q = idivide(int64(dividend*2^frc), int64(divisor), "fix");
    m_rint = rem(dividend,divisor);
    if m_q != q_int || m_rint != r_int
        printf(" Incorrect quotient and remainder. \n\r");
        printf(" dividend= %d, divisor= %d, q: %d, r_int: %d \n\r", dividend, divisor, q_int, r_int);
        printf(" q: %d r_int: %d \n\r", m_q, m_rint);
    endif

    printf(" Zero dividend nonrestoring division. \n\r");
    [q_int, r, r_int] = div_nonrestoring(dividend, divisor, frc);
    m_q = idivide(int64(dividend*2^frc), int64(divisor), "fix");
    m_rint = rem(dividend,divisor);
    if m_q != q_int || m_rint != r_int
        printf(" Incorrect quotient and remainder. \n\r");
        printf(" dividend= %d, divisor= %d, q: %d, r_int: %d \n\r", dividend, divisor, q_int, r_int);
        printf(" q: %d r_int: %d \n\r", m_q, m_rint);
    endif

    %%%%%%%%        Full length dividend and quotient testing      %%%%%%%%%%%
    printf(" Full length dividend and quotient. \n\r");
    % Full length dividend
    dividend = bitshift(int64(1), 62) - int64(1);
    dividend = int64(bitshift(dividend, (-1*frc)));
    divisor = int64(1);

    [q_int, r, r_int] = div_restoring(dividend, divisor, frc);
    m_q = idivide(int64(dividend*2^frc), int64(divisor), "fix");
    m_rint = rem(dividend,divisor);
    if m_q != q_int || m_rint != r_int
        printf(" Incorrect quotient and remainder. \n\r");
        printf(" dividend= %d, divisor= %d, q: %d, r_int: %d \n\r", dividend, divisor, q_int, r_int);
        printf(" q: %d r_int: %d \n\r", m_q, m_rint);
        div_result = -1;
    else
        printf(" Full length dividend testing passed for Restoring division.\n\r");
    endif

    [q_int, r, r_int] = div_nonrestoring(dividend, divisor, frc);
    m_q = idivide(int64(dividend*2^frc), int64(divisor), "fix");
    m_rint = rem(dividend,divisor);
    if m_q != q_int || m_rint != r_int
        printf(" Incorrect quotient and remainder. \n\r");
        printf(" dividend= %d, divisor= %d, q: %d, r_int: %d \n\r", dividend, divisor, q_int, r_int);
        printf(" q: %d r_int: %d \n\r", m_q, m_rint);
        div_result = -1;
    else
        printf(" Full length dividend testing passed for Nonrestoring division.\n\r");
    endif

    %%%%%%%%        Full length dividend and divisor testing      %%%%%%%%%%%
    printf(" Full length dividend and divisor. \n\r");
    % Full length dividend
    dividend = bitshift(int64(1), 62) - int64(1);
    dividend = int64(bitshift(dividend, (-1*frc)));
    divisor = int64(dividend);

    [q_int, r, r_int] = div_restoring(dividend, divisor, frc);
    m_q = idivide(int64(dividend*2^frc), int64(divisor), "fix");
    m_rint = rem(dividend,divisor);
    if m_q != q_int || m_rint != r_int
        printf(" Incorrect quotient and remainder. \n\r");
        printf(" dividend= %d, divisor= %d, q: %d, r_int: %d \n\r", dividend, divisor, q_int, r_int);
        printf(" q: %d r_int: %d \n\r", m_q, m_rint);
        div_result = -1;
    else
        printf(" Full length dividend/divisor testing passed for Restoring division.\n\r");
    endif

    [q_int, r, r_int] = div_nonrestoring(dividend, divisor, frc);
    m_q = idivide(int64(dividend*2^frc), int64(divisor), "fix");
    m_rint = rem(dividend,divisor);
    if m_q != q_int || m_rint != r_int
        printf(" Incorrect quotient and remainder. \n\r");
        printf(" dividend= %d, divisor= %d, q: %d, r_int: %d \n\r", dividend, divisor, q_int, r_int);
        printf(" q: %d r_int: %d \n\r", m_q, m_rint);
        div_result = -1;
    else
        printf(" Full length dividend/divisor testing passed for Nonrestoring division.\n\r");
    endif

endfunction

