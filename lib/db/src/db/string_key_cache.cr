module DB
  class StringKeyCache(T)
    @cache = {} of String => T

    def fetch(key : String) : T
      value = @cache.fetch(key, nil)
      value = @cache[key] = yield unless value
      value
    end

    def each_value
      @cache.each do |_, value|
        yield value
      end
    end

    def clear
      @cache.clear
    end
  end
end
