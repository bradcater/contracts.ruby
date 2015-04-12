require "contracts/formatters"

# rdoc
# This module contains all the builtin contracts.
# If you want to use them, first:
#
#   import Contracts
#
# And then use these or write your own!
#
# A simple example:
#
#   Contract Num, Num => Num
#   def add(a, b)
#     a + b
#   end
#
# The contract is <tt>Contract Num, Num, Num</tt>.
# That says that the +add+ function takes two numbers and returns a number.
module Contracts
  # Check that an argument is +Numeric+.
  class Num
    def self.valid? val
      val.is_a? Numeric
    end
  end

  # Check that an argument is a positive number.
  class Pos
    def self.valid? val
      val > 0
    end
  end

  # Check that an argument is a negative number.
  class Neg
    def self.valid? val
      val < 0
    end
  end

  # Check that an argument is a natural number.
  class Nat
    def self.valid? val
      val && val >= 0 && val.integer?
    end
  end

  # Passes for any argument.
  class Any
    def self.valid? val
      true
    end
  end

  # Fails for any argument.
  class None
    def self.valid? val
      false
    end
  end

  # Use this when you are writing your own contract classes.
  # Allows your contract to be called with <tt>[]</tt> instead of <tt>.new</tt>:
  #
  # Old: <tt>Or.new(param1, param2)</tt>
  #
  # New: <tt>Or[param1, param2]</tt>
  #
  # Of course, <tt>.new</tt> still works.
  class CallableClass
    include ::Contracts::Formatters
    def self.[](*vals)
      new(*vals)
    end
  end

  # Takes a variable number of contracts.
  # The contract passes if any of the contracts pass.
  # Example: <tt>Or[Fixnum, Float]</tt>
  class Or < CallableClass
    def initialize(*vals)
      @vals = vals
    end

    def valid?(val)
      @vals.any? do |contract|
        res, _ = Contract.valid?(val, contract)
        res
      end
    end

    def to_s
      @vals[0, @vals.size-1].map do |x|
        InspectWrapper.create(x)
      end.join(", ") + " or " + InspectWrapper.create(@vals[-1]).to_s
    end
  end

  # Takes a variable number of contracts.
  # The contract passes if exactly one of those contracts pass.
  # Example: <tt>Xor[Fixnum, Float]</tt>
  class Xor < CallableClass
    def initialize(*vals)
      @vals = vals
    end

    def valid?(val)
      results = @vals.map do |contract|
        res, _ = Contract.valid?(val, contract)
        res
      end
      results.count(true) == 1
    end

    def to_s
      @vals[0, @vals.size-1].map do |x|
        InspectWrapper.create(x)
      end.join(", ") + " xor " + InspectWrapper.create(@vals[-1]).to_s
    end
  end

  # Takes a variable number of contracts.
  # The contract passes if all contracts pass.
  # Example: <tt>And[Fixnum, Float]</tt>
  class And < CallableClass
    def initialize(*vals)
      @vals = vals
    end

    def valid?(val)
      @vals.all? do |contract|
        res, _ = Contract.valid?(val, contract)
        res
      end
    end

    def to_s
      @vals[0, @vals.size-1].map do |x|
        InspectWrapper.create(x)
      end.join(", ") + " and " + InspectWrapper.create(@vals[-1]).to_s
    end
  end

  # Takes a variable number of method names as symbols.
  # The contract passes if the argument responds to all
  # of those methods.
  # Example: <tt>RespondTo[:password, :credit_card]</tt>
  class RespondTo < CallableClass
    def initialize(*meths)
      @meths = meths
    end

    def valid?(val)
      @meths.all? do |meth|
        val.respond_to? meth
      end
    end

    def to_s
      "a value that responds to #{@meths.inspect}"
    end
  end

  # Takes a variable number of method names as symbols.
  # Given an argument, all of those methods are called
  # on the argument one by one. If they all return true,
  # the contract passes.
  # Example: <tt>Send[:valid?]</tt>
  class Send < CallableClass
    def initialize(*meths)
      @meths = meths
    end

    def valid?(val)
      @meths.all? do |meth|
        val.send(meth)
      end
    end

    def to_s
      "a value that returns true for all of #{@meths.inspect}"
    end
  end

  # Takes a class +A+. If argument is object of type +A+, the contract passes.
  # If it is a subclass of A (or not related to A in any way), it fails.
  # Example: <tt>Exactly[Numeric]</tt>
  class Exactly < CallableClass
    def initialize(cls)
      @cls = cls
    end

    def valid?(val)
      val.class == @cls
    end

    def to_s
      "exactly #{@cls.inspect}"
    end
  end

  # Takes a value +v+. If the argument is +.equal+ to +v+, the contract passes,
  # otherwise the contract fails.
  # Example: <tt>Eq[Class]</tt>
  class Eq < CallableClass
    def initialize(value)
      @value = value
    end

    def valid?(val)
      @value.equal?(val)
    end

    def to_s
      "to be equal to #{@value.inspect}"
    end
  end

  # Takes a variable number of contracts. The contract
  # passes if all of those contracts fail for the given argument.
  # Example: <tt>Not[nil]</tt>
  class Not < CallableClass
    def initialize(*vals)
      @vals = vals
    end

    def valid?(val)
      @vals.all? do |contract|
        res, _ = Contract.valid?(val, contract)
        !res
      end
    end

    def to_s
      "a value that is none of #{@vals.inspect}"
    end
  end

  # @private
  # Takes a collection(responds to :each) type and a contract.
  # The related argument must be of specified collection type.
  # Checks the contract against every element of the collection.
  # If it passes for all elements, the contract passes.
  # Example: <tt>CollectionOf[Array, Num]</tt>
  class CollectionOf < CallableClass
    def initialize(collection_class, contract)
      @collection_class = collection_class
      @contract = contract
    end

    def valid?(vals)
      return false unless vals.is_a?(@collection_class)
      vals.all? do |val|
        res, _ = Contract.valid?(val, @contract)
        res
      end
    end

    def to_s
      "a collection #{@collection_class} of #{@contract}"
    end

    class Factory
      def initialize(collection_class, &before_new)
        @collection_class = collection_class
        @before_new = before_new
      end

      def new(contract)
        @before_new && @before_new.call
        CollectionOf.new(@collection_class, contract)
      end

      alias_method :[], :new
    end
  end

  # Takes a contract. The related argument must be an array.
  # Checks the contract against every element of the array.
  # If it passes for all elements, the contract passes.
  # Example: <tt>ArrayOf[Num]</tt>
  ArrayOf = CollectionOf::Factory.new(Array)

  # Takes a contract. The related argument must be a set.
  # Checks the contract against every element of the set.
  # If it passes for all elements, the contract passes.
  # Example: <tt>SetOf[Num]</tt>
  SetOf = CollectionOf::Factory.new(Set) do
    require "set"
  end

  # Used for <tt>*args</tt> (variadic functions). Takes a contract
  # and uses it to validate every element passed in
  # through <tt>*args</tt>.
  # Example: <tt>Args[Or[String, Num]]</tt>
  class Args < CallableClass
    attr_reader :contract
    def initialize(contract)
      @contract = contract
    end

    def to_s
      "Args[#{@contract}]"
    end
  end

  class Bool
    def self.valid? val
      val.is_a?(TrueClass) || val.is_a?(FalseClass)
    end
  end

  # Use this to specify the Hash characteristics. Takes two contracts,
  # one for hash keys and one for hash values.
  # Example: <tt>HashOf[Symbol, String]</tt>
  class HashOf < CallableClass
    def initialize(key, value = nil)
      if value
        @key   = key
        @value = value
      else
        @key   = key.keys.first
        @value = key[@key]
      end
    end

    def valid?(hash)
      keys_match = hash.keys.map { |k| Contract.valid?(k, @key) }.all?
      vals_match = hash.values.map { |v| Contract.valid?(v, @value) }.all?

      [keys_match, vals_match].all?
    end

    def to_s
      "Hash<#{@key}, #{@value}>"
    end
  end

  # Takes a Contract.
  # The contract passes if the contract passes or the given value is nil.
  # Maybe(foo) is equivalent to Or[foo, nil].
  class Maybe < Or
    def initialize(*vals)
      super(*(vals + [nil]))
    end
  end

  # Used to define contracts on functions passed in as arguments.
  # Example: <tt>Func[Num => Num] # the function should take a number and return a number</tt>
  class Func < CallableClass
    attr_reader :contracts
    def initialize(*contracts)
      @contracts = contracts
    end
  end
end
