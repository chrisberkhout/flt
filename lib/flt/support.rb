module Flt
  module Support
    # This class assigns bit-values to a set of symbols
    # so they can be used as flags and stored as an integer.
    #   fv = FlagValues.new(:flag1, :flag2, :flag3)
    #   puts fv[:flag3]
    #   fv.each{|f,v| puts "#{f} -> #{v}"}
    class FlagValues

      #include Enumerator

      class InvalidFlagError < StandardError
      end
      class InvalidFlagTypeError < StandardError
      end


      # The flag symbols must be passed; values are assign in increasing order.
      #   fv = FlagValues.new(:flag1, :flag2, :flag3)
      #   puts fv[:flag3]
      def initialize(*flags)
        @flags = {}
        value = 1
        flags.each do |flag|
          raise InvalidFlagType,"Flags must be defined as symbols or classes; invalid flag: #{flag.inspect}" unless flag.kind_of?(Symbol) || flag.instance_of?(Class)
          @flags[flag] = value
          value <<= 1
        end
      end

      # Get the bit-value of a flag
      def [](flag)
        v = @flags[flag]
        raise InvalidFlagError, "Invalid flag: #{flag}" unless v
        v
      end

      # Return each flag and its bit-value
      def each(&blk)
        if blk.arity==2
          @flags.to_a.sort_by{|f,v|v}.each(&blk)
        else
          @flags.to_a.sort_by{|f,v|v}.map{|f,v|f}.each(&blk)
        end
      end

      def size
        @flags.size
      end

      def all_flags_value
        (1 << size) - 1
      end

    end

    # This class stores a set of flags. It can be assign a FlagValues
    # object (using values= or passing to the constructor) so that
    # the flags can be store in an integer (bits).
    class Flags

      class Error < StandardError
      end
      class InvalidFlagError < Error
      end
      class InvalidFlagValueError < Error
      end
      class InvalidFlagTypeError < Error
      end

      # When a Flag object is created, the initial flags to be set can be passed,
      # and also a FlagValues. If a FlagValues is passed an integer can be used
      # to define the flags.
      #    Flags.new(:flag1, :flag3, FlagValues.new(:flag1,:flag2,:flag3))
      #    Flags.new(5, FlagValues.new(:flag1,:flag2,:flag3))
      def initialize(*flags)
        @values = nil
        @flags = {}

        v = 0

        flags.flatten!

        flags.each do |flag|
          case flag
            when FlagValues
              @values = flag
            when Symbol, Class
              @flags[flag] = true
            when Integer
              v |= flag
            when Flags
              @values = flag.values
              @flags = flag.to_h.dup
            else
              raise InvalidFlagTypeError, "Invalid flag type for: #{flag.inspect}"
          end
        end

        if v!=0
          raise InvalidFlagTypeError, "Integer flag values need flag bit values to be defined" if @values.nil?
          self.bits = v
        end

        if @values
          # check flags
          @flags.each_key{|flag| check flag}
        end

      end

      def dup
        Flags.new(self)
      end

      # Clears all flags
      def clear!
        @flags = {}
      end

      # Sets all flags
      def set!
        if @values
          self.bits = @values.all_flags_value
        else
          raise Error,"No flag values defined"
        end
      end

      # Assign the flag bit values
      def values=(fv)
        @values = fv
      end

      # Retrieves the flag bit values
      def values
        @values
      end

      # Retrieves the flags as a bit-vector integer. Values must have been assigned.
      def bits
        if @values
          i = 0
          @flags.each do |f,v|
            bit_val = @values[f]
            i |= bit_val if v && bit_val
          end
          i
        else
          raise Error,"No flag values defined"
        end
      end

      # Sets the flags as a bit-vector integer. Values must have been assigned.
      def bits=(i)
        if @values
          raise Error, "Invalid bits value #{i}" if i<0 || i>@values.all_flags_value
          clear!
          @values.each do |f,v|
            @flags[f]=true if (i & v)!=0
          end
        else
          raise Error,"No flag values defined"
        end
      end

      # Retrieves the flags as a hash.
      def to_h
        @flags
      end

      # Same as bits
      def to_i
        bits
      end

      # Retrieve the setting (true/false) of a flag
      def [](flag)
        check flag
        @flags[flag]
      end

      # Modifies the setting (true/false) of a flag.
      def []=(flag,value)
        check flag
        case value
          when true,1
            value = true
          when false,0,nil
            value = false
          else
            raise InvalidFlagValueError, "Invalid value: #{value.inspect}"
        end
        @flags[flag] = value
        value
      end

      # Sets (makes true) one or more flags
      def set(*flags)
        flags = flags.first if flags.size==1 && flags.first.instance_of?(Array)
        flags.each do |flag|
          if flag.kind_of?(Flags)
            #if @values && other.values && compatible_values(other_values)
            #  self.bits |= other.bits
            #else
              flags.concat other.to_a
            #end
          else
            check flag
            @flags[flag] = true
          end
        end
      end

      # Clears (makes false) one or more flags
      def clear(*flags)
        flags = flags.first if flags.size==1 && flags.first.instance_of?(Array)
        flags.each do |flag|
          if flag.kind_of?(Flags)
            #if @values && other.values && compatible_values(other_values)
            #  self.bits &= ~other.bits
            #else
              flags.concat other.to_a
            #end
          else
            check flag
            @flags[flag] = false
          end
        end
      end

      # Sets (makes true) one or more flags (passes as an array)
      def << (flags)
        if flags.kind_of?(Array)
          set(*flags)
        else
          set(flags)
        end
      end

      # Iterate on each flag/setting pair.
      def each(&blk)
        if @values
          @values.each do |f,v|
            blk.call(f,@flags[f])
          end
        else
          @flags.each(&blk)
        end
      end

      # Iterate on each set flag
      def each_set
        each do |f,v|
          yield f if v
        end
      end

      # Iterate on each cleared flag
      def each_clear
        each do |f,v|
          yield f if !v
        end
      end

      # returns true if any flag is set
      def any?
        if @values
          bits != 0
        else
          to_a.size>0
        end
      end

      # Returns the true flags as an array
      def to_a
        a = []
        each_set{|f| a << f}
        a
      end

      def to_s
        "[#{to_a.map{|f| f.to_s.split('::').last}.join(', ')}]"
      end

      def inspect
        txt = "#{self.class.to_s}#{to_s}"
        txt << " (0x#{bits.to_s(16)})" if @values
        txt
      end


      def ==(other)
        if @values && other.values && compatible_values?(other.values)
          bits == other.bits
        else
          to_a.map{|s| s.to_s}.sort == other.to_a.map{|s| s.to_s}.sort
        end
      end



      private
      def check(flag)
        raise InvalidFlagType,"Flags must be defined as symbols or classes; invalid flag: #{flag.inspect}" unless flag.kind_of?(Symbol) || flag.instance_of?(Class)

        @values[flag] if @values # raises an invalid flag error if flag is invalid
        true
      end

      def compatible_values?(v)
        #@values.object_id==v.object_id
        @values == v
      end

    end

    module_function

    # Constructor for FlagValues
    def FlagValues(*params)
      if params.size==1 && params.first.kind_of?(FlagValues)
        params.first
      else
        FlagValues.new(*params)
      end
    end

    # Constructor for Flags
    def Flags(*params)
      if params.size==1 && params.first.kind_of?(Flags)
        params.first
      else
        Flags.new(*params)
      end
    end

    # Floating-point reading and printing (from/to text literals).
    #
    # Here are methods for floating-point reading using algorithms by William D. Clinger and
    # printing using algorithms by Robert G. Burger and R. Kent Dybvig.
    #
    # Reading and printing can also viewed as floating-point conversion betwen a fixed-precision
    # floating-point format (the floating-point numbers) and and a free floating-point format (text) wich
    # may use different numerical bases.
    #
    # The Reader class implements the Clinger reading algorithm which converts a free form numeric value
    # (as a text literal, i.e. a free floating-point format, usually in base 10) which is taken
    # as an exact value, to a correctly-rounded floating-point of specified precision and with a
    # specified rounding mode.
    #
    # The Formatter class implements the Burger-Dybvig printing algorithm which converts a
    # fixed-precision floating point value and produces a text literal in same base, usually 10,
    # (equivalently, it produces a floating-point free-format value) so that it rounds back to
    # the original value (with some specified rounding-mode or any round-to-nearest mode) and with
    # the same original precision (e.g. using the Clinger algorithm)

    # Clinger algorithms to read floating point numbers from text literas with correct rounding.
    # from his paper: "How to Read Floating Point Numbers Accurately"
    # (William D. Clinger)
    class Reader

      def initialize
        @exact = nil
      end

      def exact?
        @exact
      end

      # Given exact integers f and e, with f nonnegative, returns the floating-point number
      # closest to f * eb**e
      # (eb is the input radix)
      #
      # This is Clinger's +AlgorithmM+ modified to handle denormalized numbers and cope with overflow.
      def read(context, round_mode, sign, f, e, eb=10) # ceiling & floor must be swapped for negative numbers
        if sign == -1
          if rounding == :ceiling
            rounding = :floor
          elsif rounding == :floor
            rounding = :ceiling
          end
        end

        if e<0
         u,v,k = f,eb**(-e),0
        else
          u,v,k = f*(eb**e),1,0
        end

        if exact_mode = context.exact?
          exact_mode = :quiet if !context.traps[Num::Inexact]
          n = [(Math.log(u)/Math.log(2)).ceil,1].max # This is very rough
          context.precision = n
        else
          n = context.precision
        end
        min_e = context.etiny
        max_e = context.etop

        rp_n = context.num_class.int_radix_power(n)
        rp_n_1 = context.num_class.int_radix_power(n-1)
        r = context.num_class.radix
        loop do
           x = u.div(v) # bottleneck
           # overflow if k>=max_e
           if (x>=rp_n_1 && x<rp_n) || k==min_e || k==max_e
              z, exact = Reader.ratio_float(context,u,v,k,round_mode)
              context.exact = exact_mode if exact_mode
              @exact = exact
              return z.copy_sign(sign)
           elsif x<rp_n_1
             u *= r
             k -= 1
           elsif x>=rp_n
             v *= r
             k += 1
           end
        end

      end

      # Given exact positive integers u and v with beta**(n-1) <= u/v < beta**n
      # and exact integer k, returns the floating point number closest to u/v * beta**n
      # (beta is the floating-point radix)
      def self.ratio_float(context, u, v, k, round_mode)
        # since this handles only positive numbers and ceiling and floor
        # are not symmetrical, they should have been swapped before calling this.
        q = u.div v
        r = u-q*v
        v_r = v-r
        z = context.Num(+1,q,k)
        exact = (r==0)
        if (round_mode == :down || round_mode == :floor)
          # z = z
        elsif (round_mode == :up || round_mode == :ceiling) && r>0
          z = z.next_plus(context)
        elsif r<v_r
          # z = z
        elsif r>v_r
          z = z.next_plus(context)
        else
          # tie
          if (round_mode == :half_down) || (round_mode == :half_even && ((q%2)==0)) ||
             (round_mode == :down) || (round_mode == :floor)
             # z = z
          else
            z = z.next_plus(context)
          end
        end
        return z, exact
      end

    end # Reader

    # Burger and Dybvig free formatting algorithm,
    # from their paper: "Printing Floating-Point Numbers Quickly and Accurately"
    # (Robert G. Burger, R. Kent Dybvig)
    #
    # This algorithm formats arbitrary base floating point numbers as decimal
    # text literals. The floating-point (with fixed precision) is interpreted as an approximated
    # value, representing any value in its 'rounding-range' (the interval where all values round
    # to the floating-point value, with the given precision and rounding mode).
    # An alternative approach which is not taken here would be to represent the exact floating-point
    # value with some given precision and rounding mode requirements; that can be achieve with
    # Clinger algorithm for finite (non-exact) precision.
    #
    # The variables used by the algorithm are stored in instance variables:
    # @v - The number to be formatted = @f*@b**@e
    # @b - The numberic base of the input floating-point representation of @v
    # @f - The significand or characteristic (fraction)
    # @e - The exponent
    #
    # Quotients of integers will be used to hold the magnitudes:
    # @s is the denominator of all fractions
    # @r numerator of @v: @v = @r/@s
    # @m_m numerator of the distance from the rounding-range lower limit, l, to @v: @m_m/@s = (@v - l)
    # @m_p numerator of the distance from @v to the rounding-range upper limit, u: @m_p/@s = (u - @v)
    # All numbers in the randound-range are rounded to @v (with the given precision p)
    # @k scale factor that is applied to the quotients @r/@s, @m_m/@s and @m_p/@s to put the first
    # significant digit right after the radix point. @b**@k is the first power of @b >= u
    #
    # The rounding range of @v is the interval of values that round to @v under the runding-mode.
    # If the rounding mode is one of the round-to-nearest variants (even, up, down), then
    # it is ((v+v-)/2 = (@v-@m_m)/@s, (v+v+)/2 = (@v+@m_)/2) whith the boundaries open or closed as explained below.
    # In this case:
    #   @m_m/@s = (@v - (v + v-)/2) where v- = @v.next_minus is the lower adjacent to v floating point value
    #   @m_p/@s = ((v + v+)/2 - @v) where v+ = @v.next_plus is the upper adjacent to v floating point value
    # If the rounding is directed, then the rounding interval is either (v-, @v] or [@v, v+]
    # @roundl is true if the lower limit of the rounding range is closed (i.e., if l rounds to @v)
    # @roundh is true if the upper limit of the rounding range is closed (i.e., if u rounds to @v)
    # if @roundh, then @k is the minimum @k with (@r+@m_p)/@s <= @output_b**@k
    #   @k = ceil(logB((@r+@m_p)/2)) with lobB the @output_b base logarithm
    # if @roundh, then @k is the minimum @k with (@r+@m_p)/@s < @output_b**@k
    #   @k = 1+floor(logB((@r+@m_p)/2))
    #
    # @output_b is the output base
    # @output_min_e is the output minimum exponent
    # p is the input floating point precision
    class Formatter

      # This Object-oriented implementation is slower than the functional one for two reasons:
      # * The overhead of object creation
      # * The use of instance variables instead of local variables
      # But if scale is optimized or local variables are used in the inner loops, then this implementation
      # is on par with the functional one for Float and it is more efficient for Flt types, where the variables
      # passed as parameters hold larger objects.

      def initialize(input_b, input_min_e, output_b)
        @b = input_b
        @min_e = input_min_e
        @output_b = output_b
        @round_up = nil
        @adjusted_digits = @digits = nil
      end

      # This method converts v = f*b**e into a sequence of output_b-base digits,
      # so that if the digits are converted back to a floating-point value
      # of precision p (correctly rounded), the result is v.
      # If round_mode is not nil, just enough digits to produce v using
      # that rounding is used; otherwise enough digits to produce v with
      # any rounding are delivered.
      #
      # If the +all+ parameter is true, all significant digits are generated without rounding,
      # i.e. all digits that, if used on input, cannot arbitrarily change
      # preserving the parsed value of the floating point number. Since the digits are not rounded
      # more digits may be needed to assure round-trip value preservation.
      # This is useful to generate a fixed number of digits or if
      # as many digits as possible are required.
      # Beware: this may lead to an infinite-loop if v cannot be represented exactly in the output-base;
      # e.g. formatting '0.1' (as a decimal floating-point number) in base 2.
      #
      # In this case, the round_up flag is set to indicate that the last digits should be
      # rounded up.
      #
      # Note that the round_mode here is not the rounding mode applied to the output;
      # it is the rounding mode that applied to *input* preserves the original floating-point
      # value (with the same precision as input).
      # should be rounded-up.
      def format(v, f, e, round_mode, p=nil, all=false)
        # TODO: consider removing parameters f,e and using v.split instead
        @minus = (v < 0)
        @v = v.abs
        @f = f.abs
        @e = e
        @round_mode = round_mode
        @all_digits = all
        p ||= v.class.context.precision

        # adjust the rounding mode to work only with positive numbers
        if @minus
          if @round_mode == :ceiling
            @round_mode = :floor
          elsif @round_mode == :floor
            @round_mode = :ceiling
          end
        end

        # determine the high,low inclusion flags of the rounding limits
        case @round_mode
          when :half_even
            # rounding rage is (v-m-,v+m+) if v is odd and [v+m-,v+m+] if even
            @round_l = @round_h = ((@f%2)==0)
          when :up, :ceiling
            # rounding rage is (v-,v]
            # ceiling is treated here assuming f>0
            @round_l, @round_h = false, true
          when :down, :floor
            # rounding rage is [v,v+)
            # floor is treated here assuming f>0
            @round_l, @round_h = true, false
          when :half_up
            # rounding rage is [v+m-,v+m+)
            @round_l, @round_h = true, false
          when :half_down
            # rounding rage is (v+m-,v+m+]
            @round_l, @round_h = false, true
          else
            # Here assume only that round-to-nearest will be used, but not which variant of it
            # The result is valid for any rounding (to nearest) but may produce more digits
            # than stricly necessary for specific rounding modes.
            # That is, enough digits are generated so that when the result is
            # converted to floating point with the specified precision and
            # correct rounding (to nearest), the result is the original number.
            # rounding range is (v+m-,v+m+)
            @round_l = @round_h = false
        end

        # TODO: use next_minus, next_plus instead of direct computing, don't require min_e
        # Now compute the working quotients @r/@s, @m_p/@s = (v+ - @v), @m_m/@s = (@v - v-) and scale them.
        if @e >= 0
          if @f != b_power(p-1)
            be = b_power(@e)
            @r, @s, @m_p, @m_m = @f*be*2, 2, be, be
          else
            be = exptt(b, e)
            be1 = be*@b
            @r, @s, @m_p, @m_m = @f*be1*2, @b*2, be1, be
          end
        else
          if @e==@min_e or @f != b_power(p-1)
            @r, @s, @m_p, @m_m = @f*2, b_power(-@e)*2, 1, 1
          else
            @r, @s, @m_p, @m_m = @f*@b*2, b_power(1-@e)*2, @b, 1
          end
        end
        @k = 0
        scale_optimized!


        # The value to be formatted is @v=@r/@s; m- = @m_m/@s = (@v - v-)/@s; m+ = @m_p/@s = (v+ - @v)/@s
        # Now adjust @m_m, @m_p so that they define the rounding range
        case @round_mode
        when :up, :ceiling
          # ceiling is treated here assuming @f>0
          # rounding range is -v,@v
          @m_m, @m_p = @m_m*2, 0
        when :down, :floor
          # floor is treated here assuming #f>0
          # rounding range is @v,v+
          @m_m, @m_p = 0, @m_p*2
        else
          # rounding range is v-,v+
          # @m_m, @m_p = @m_m, @m_p
        end

        # Now m_m, m_p define the rounding range
        all ? generate_max : generate

      end

      # Access result of format operation: scaling (position of radix point) and digits
      def digits
        return @k, @digits
      end

      attr_reader :round_up

      # Access rounded result of format operation: scaling (position of radix point) and digits
      def adjusted_digits
        if @adjusted_digits.nil? && !@digits.nil?
          if @round_up
            base = @output_b
            dec_pos = @k
            digits = @digits.dup
            # carry = roundup ? 1 : 0
            # digits = digits.reverse.map{|d| d += carry; d>=base ? 0 : (carry=0;d)}.reverse
            # if carry != 0
            #   digits.unshift carry
            #   dec_pos += 1
            # end
            i = digits.size - 1
            while i>=0
              digits[i] += 1
              if digits[i] == base
                digits[i] == 0
              else
                break
              end
              i -= 1
            end
            if i<0
              dec_pos += 1
              digits.unshift 1
            end
            @adjusted_k = dec_pos
            @adjusted_digits = digits
          else
            @adjusted_k = @k
            @adjusted_digits = @digits
          end
        end
        return @adjusted_k, @adjusted_digits
      end

      # Given r/s = v (number to convert to text), m_m/s = (v - v-)/s, m_p/s = (v+ - v)/s
      # Scale the fractions so that the first significant digit is right after the radix point, i.e.
      # find k = ceil(logB((r+m_p)/s)), the smallest integer such that (r+m_p)/s <= B^k
      # if k>=0 return:
      #  r=r, s=s*B^k, m_p=m_p, m_m=m_m
      # if k<0 return:
      #  r=r*B^k, s=s, m_p=m_p*B^k, m_m=m_m*B^k
      #
      # scale! is a general iterative method using only (multiprecision) integer arithmetic.
      def scale_original!(really=false)
        loop do
          if (@round_h ? (@r+@m_p >= @s) : (@r+@m_p > @s)) # k is too low
            @s *= @output_b
            @k += 1
          elsif (@round_h ? ((@r+@m_p)*@output_b<@s) : ((@r+@m_p)*@output_b<=@s)) # k is too high
            @r *= @output_b
            @m_p *= @output_b
            @m_m *= @output_b
            @k -= 1
          else
            break
          end
        end
      end
      # using local vars instead of instance vars: it makes a difference in performance
      def scale!
        r, s, m_p, m_m, k,output_b = @r, @s, @m_p, @m_m, @k,@output_b
        loop do
          if (@round_h ? (r+m_p >= s) : (r+m_p > s)) # k is too low
            s *= output_b
            k += 1
          elsif (@round_h ? ((r+m_p)*output_b<s) : ((r+m_p)*output_b<=s)) # k is too high
            r *= output_b
            m_p *= output_b
            m_m *= output_b
            k -= 1
          else
            @s = s
            @r = r
            @m_p = m_p
            @m_m = m_m
            @k = k
            break
          end
        end
      end

      def b_power(n)
        @b**n
      end

      def output_b_power(n)
        @output_b**n
      end

      def generate_max
        @round_up = false
        list = []
        r, s, m_p, m_m, = @r, @s, @m_p, @m_m
        loop do
          d,r = (r*@output_b).divmod(s)
          # TODO: detect repetition of r value to avoid infinite loop (can only happen if (output_b % b) != 0)
          # TODO: optionally limit the maximum number of digits
          m_p *= @output_b
          m_m *= @output_b

          list << d

          tc1 = @round_l ? (r<=m_m) : (r<m_m)
          tc2 = @round_h ? (r+m_p >= s) : (r+m_p > s)

          if tc1 && tc2
            @round_up = true if r*2 >= s
            break
          end
        end
        @digits = list
      end

      def generate
        list = []
        r, s, m_p, m_m, = @r, @s, @m_p, @m_m
        loop do
          d,r = (r*@output_b).divmod(s)
          m_p *= @output_b
          m_m *= @output_b
          tc1 = @round_l ? (r<=m_m) : (r<m_m)
          tc2 = @round_h ? (r+m_p >= s) : (r+m_p > s)

          if not tc1
            if not tc2
              list << d
            else
              list << d+1
              break
            end
          else
            if not tc2
              list << d
              break
            else
              if r*2 < s
                list << d
                break
              else
                list << d+1
                break
              end
            end
          end

        end
        @digits = list
      end

      ESTIMATE_FLOAT_LOG_B = {2=>1/Math.log(2), 10=>1/Math.log(10), 16=>1/Math.log(16)}
      # scale_o1! is an optimized version of scale!; it requires an additional parameters with the
      # floating-point number v=r/s
      #
      # It uses a Float estimate of ceil(logB(v)) that may need to adjusted one unit up
      # TODO: find easy to use estimate; determine max distance to correct value and use it for fixing,
      #       or use the general scale! for fixing (but remembar to multiply by exptt(...))
      #       (determine when Math.log is aplicable, etc.)
      def scale_optimized!
        return scale! if @v.zero?

        # 1. compute estimated_scale

        # 1.1. try to use Float logarithms (Math.log)
        v = @v
        v_abs = v.abs
        v_flt = v_abs.to_f
        b = @output_b
        log_b = ESTIMATE_FLOAT_LOG_B[b]
        log_b = ESTIMATE_FLOAT_LOG_B[b] = 1.0/Math.log(b) if log_b.nil?
        estimated_scale = nil
        fixup = false
        begin
          l = ((b==10) ? Math.log10(v_flt) : Math.log(v_flt)*log_b)
          estimated_scale =(l - 1E-10).ceil
          fixup = true
        rescue
          # rescuing errors is more efficient than checking (v_abs < Float::MAX.to_i) && (v_flt > Float::MIN) when v is a Flt
        else
          # estimated_scale = nil
        end

        # 1.2. Use Flt::DecNum logarithm
        if estimated_scale.nil?
          v.to_decimal_exact(:precision=>12) if v.is_a?(BinNum)
          if v.is_a?(DecNum)
            l = nil
            DecNum.context(:precision=>12) do
              case b
              when 10
                l = v_abs.log10
              else
                l = v_abs.ln/Flt.DecNum(b).ln
              end
            end
            l -= Flt.DecNum(+1,1,-10)
            estimated_scale = l.ceil
            fixup = true
          end
        end

        # 1.3 more rough Float aproximation
          # TODO: optimize denominator, correct numerator for more precision with first digit or part
          # of the coefficient (like _log_10_lb)
        estimated_scale ||= (v.adjusted_exponent.to_f * Math.log(v.class.radix) * log_b).ceil

        if estimated_scale >= 0
          @k = estimated_scale
          @s *= output_b_power(estimated_scale)
        else
          sc = output_b_power(-estimated_scale)
          @k = estimated_scale
          @r *= sc
          @m_p *= sc
          @m_m *= sc
        end
        fixup ? scale_fixup! : scale!

      end

      # fix up scaling (final step): specialized version of scale!
      # This performs a single up scaling step, i.e. behaves like scale2, but
      # the input must be at least one step down from the final result
      def scale_fixup!
        if (@round_h ? (@r+@m_p >= @s) : (@r+@m_p > @s)) # too low?
          @s *= @output_b
          @k += 1
        end
      end

    end

    module AuxiliarFunctions

      module_function

      # Number of bits in binary representation of the positive integer n, or 0 if n == 0.
      def _nbits(x)
        raise  TypeError, "The argument to _nbits should be nonnegative." if x < 0
        if x.is_a?(Fixnum)
          return 0 if x==0
          x.to_s(2).length
        elsif x <= NBITS_LIMIT
          Math.frexp(x).last
        else
          n = 0
          while x!=0
            y = x
            x >>= NBITS_BLOCK
            n += NBITS_BLOCK
          end
          n += y.to_s(2).length - NBITS_BLOCK if y!=0
          n
        end
      end
      NBITS_BLOCK = 32
      NBITS_LIMIT = Math.ldexp(1,Float::MANT_DIG).to_i

      def detect_float_rounding
        x = x = Math::ldexp(1, Float::MANT_DIG+1) # 10000...00*Float::RADIX**2 == Float::RADIX**(Float::MANT_DIG+1)
        y = x + Math::ldexp(1, 2)                 # 00000...01*Float::RADIX**2 == Float::RADIX**2
        h = Float::RADIX/2
        b = h*Float::RADIX
        z = Float::RADIX**2 - 1
        if x + 1 == y
          if (y + 1 == y) && Float::RADIX==10
            :up05
          elsif -x - 1 == -y
            :up
          else
            :ceiling
          end
        else # x + 1 == x
          if x + z == x
            if -x - z == -x
              :down
            else
              :floor
            end
          else # x + z == y
            # round to nearest
            if x + b == x
              if y + b == y
                :half_down
              else
                :half_even
              end
            else # x + b == y
              :half_up
            end
          end
        end

      end # Formatter

    end # AuxiliarFunctions

  end # Support




end # Flt