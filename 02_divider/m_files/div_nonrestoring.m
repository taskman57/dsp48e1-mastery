function [q, r, rint] = div_nonrestoring(dividend, divisor, frc)
    dividend = int64(dividend);
    d = int64(divisor);

    if dividend > 0
        % Count bit-width using integer shifts instead of double log2
        n = 0;
        temp = dividend;
        while temp > 0
            n = n + 1;
            temp = bitshift(temp, -1);
        endwhile

        % Safe integer bitmask
        if (n + frc) >= 63
            mask = intmax('int64');
        else
            mask = bitshift(int64(1), n + frc) - int64(1);
        endif

        q = int64(0);
        r = int64(0);
        rint = int64(0);

        for i = 1:(n + frc)
            % 2r + bit (using signed int64 addition instead of double multiplication)
            r = r + r;
            if i <= n
                if bitget(dividend, (n + 1 - i)) == 1
                    r = r + int64(1);
                endif
            endif

            % Clear bit 63 before shifting q left to avoid touching the sign bit
            q = bitand(q, bitshift(intmax('int64'), -1));
            q = int64(bitand(bitshift(q, 1), mask));

            % Non-restoring add/subtract step
            if r < 0
                r = r + d;
            else
                r = r - d;
            endif

            if r >= 0
                q = q + int64(1);
            endif

            if i == n                       % store integer remainder before frc iteration
                if r >= 0
                    rint = r;
                else
                    rint = r + d;
                endif
            endif
        endfor

        % Final remainder restoration if the last cycle ended negative
        if r < 0
            r = r + d;
        endif
    else
        q = int64(0);
        r = int64(0);
        rint = int64(0);
    endif
endfunction

