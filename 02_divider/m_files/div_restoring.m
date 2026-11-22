function [q, r, rint] = div_restoring(dividend, divisor, frc)
    dividend = int64(dividend);
    n = 0;
    temp = int64(dividend);
    d = int64(divisor);
    while temp > 0
        n = n + 1;
        temp = bitshift(temp, -1);
    endwhile
    if (n + frc) >= 63
        mask = intmax('int64');
    else
        mask = bitshift(int64(1), n + frc) - int64(1);
    endif
    q = int64(0);
    r = int64(0);
    rint = int64(0);
    for i=1:n+frc
        r = int64(bitshift(r, 1));
        if i<= n
            if bitget(dividend,(n+1-i)) == 1
                r = r + int64(1);
            endif
        endif
        % Clear bit 63 before shifting left to avoid touching the sign bit
        q = bitand(q, bitshift(intmax('int64'), -1));
        q = int64(bitand(bitshift(q,1),mask));
        r = r - d;
        if r >= 0
            q = q + int64(1);
        else
            r = r + d;
        endif
        if i == n                        % store integer remainder before frc iteration
            rint = r;
        endif
    endfor
endfunction
