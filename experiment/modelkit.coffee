
# identity hash
ihash: (->
    nextValue: 0
    ihash: (value) ->
        return value.toString() unless value instanceof Object
        return value.__ihash || (value.__ihash = "#" + ++nextValue)
)()


class ObservableValue
    constructor: (initialValue, cause) ->
        @value: null
        this.set initialValue, (cause || 'initial') if initialValue?
        
    get: -> @value
        
    set: (value, cause) ->
        oldValue: @value
        @value: value
        Mo.changed this, 'changed', { cause: cause, value: value, oldValue: oldValue }
        
    reproduce: ->
        [{ type: 'changed', value: @value, oldValue: undefined }]
        
    replay: (e) -> this.set e.value, e.cause
        

class ObservableSet
    constructor: (initialElements, cause) ->
        this.addAll initialElements, (cause || 'initial') if initialElements?
        
    contains: (el) ->
        this.hasOwnProperty ihash el
        
    add: (el, cause) ->
        hash: ihash el
        if this.hasOwnProperty hash
            false
        else
            this[hash] = el
            Mo.changed this, 'added', { cause: cause, value: el }
            true
            
    addAll: (els, cause) ->
        for el in els
            this.add el, cause
        
    remove: (el, cause) ->
        hash: ihash el
        if this.hasOwnProperty hash
            delete this[hash]
            Mo.changed this, 'removed', { cause: cause, value: el }
            true
        else
            false
            
    clear: (cause) ->
        for hash, el of this when hash[0] == '#'
            delete this[hash]
            Mo.changed this, 'removed', { cause: cause, value: el }
        null
        
    get: ->
        v for hash, v of this when hash[0] == '#'
        
    set: (newValues, cause) ->
        newValues = [] if newValues == null
        newValuesHash = {}
        for v in newValues
            newValuesHash[ihash v] = v
        for hash, v of this when hash[0] == '#'
            if newValuesHash.hasOwnProperty hash
                delete newValuesHash[hash]  # unchanged
            else
                delete this[hash]
                Mo.changed this, 'removed', { cause: cause, value: v }
        for hash, v of newValuesHash
            this[hash] = v
            Mo.changed this, 'added', { cause: cause, value: v }
        undefined
        
    reproduce: ->
        { type: 'added', value: el } for hash, el of this when hash[0] == '#'
        
    replay: (e) ->
        switch e.type
            when 'added'   then this.add e.value, e.cause
            when 'removed' then this.add e.value, e.cause
        
    
class ObservableList
    
    constructor: (initialItems, cause) ->
        @items = []
        this.addAll initialItems, (cause || 'initial') if initialItems?
        
    add: (item, cause) -> this.insert @items.length, item, cause
    
    addAll: (items, cause) ->
        for item in items
            this.add item, cause
    
    insert: (pos, item, cause) ->
        @items.splice pos, 0, item
        Mo.changed this, 'added', { cause: cause, value: item, pos: pos }
    
    remove: (pos, cause) ->
        item: @items[pos]
        @items.splice pos, 1
        Mo.changed this, 'removed', { cause: cause, value: item, pos: pos }
        
    clear: (cause) ->
        len: @items.length
        i: len - 1
        while i >= 0
            Mo.changed this, 'removed', { cause: cause, value: @items[i], pos: i }
            --i
        @items = []
        
    get: -> @items
    
    set: (newItems, cause) ->
        newItems = [] if newItems == null
        # check for a trivial case
        return if newItems.length == @items.length && _(_.zip @items, newItems).all (a, b) -> (a == b)
        this.clear cause
        this.addAll newItems, cause
        
    reproduce: ->
        { type: 'added', value: @items[i], pos: i } for i in [0 ... @items.length]
        
    replay: (e) ->
        switch e.type
            when 'added'   then this.insert e.pos, e.value, e.cause
            when 'removed' then this.remove e.pos, e.cause


class ObservableMap
    
    constructor: ->
        @keys = {}
        @values = {}
    
    at: (key) -> @values[ihash key]
    
    put: (key, value, cause) ->
        hash: ihash key
        if @values.hasOwnProperty hash
            oldValue: @values[hash]
            @values[hash] = value
            Mo.changed this, 'changed', { cause: cause, key: key, value: value, oldValue: oldValue }
        else
            @keys[hash] = key
            @values[hash] = value
            Mo.changed this, 'added', { cause: cause, key: key, value: value }
            
    putAll: (pairs, cause) ->
        for pair in pairs
            [k, v] = pair
            this.put k, v, cause
        
    remove: (key, cause) ->
        hash: ihash key
        if @values.hasOwnProperty hash
            delete @keys[hash]
            delete @values[hash]
            Mo.changed this, 'removed', { cause: cause, key: key, value: value }
            
    clear: (cause) ->
        for hash, value of @values
            key: @keys[hash]
            Mo.changed this, 'removed', { cause: cause, key: key, value: value }
        @keys = {}
        @values = {}
        null
        
    get: -> [@keys[hash], value] for hash, value of @values
        
    set: (pairs, cause) ->
        pairs = [] if pairs == null
        this.clear cause
        this.putAll pairs, cause
        
    reproduce: -> { type: 'added', key: @keys[hash], value: value } for hash, value of @values
        
    replay: (e) ->
        switch e.type
            when 'added'   then this.put e.key, e.value, e.cause
            when 'changed' then this.put e.key, e.value, e.cause
            when 'removed' then this.remove e.key, e.cause
        
        
class ComputedMapping
    
    constructor: (baseSet, map) ->
        @values = {}
        @keys = {}
        
        Mo.sub baseSet, {
            added: (e) =>
                key: e.value
                hash: ihash key
                value: map key
                if value
                    @values[hash] = value
                    @keys[hash] = key
                    Mo.changed this, 'added', { key: key, value: value, cause: e.cause }
            
            removed: (e) =>
                key: e.value
                hash: ihash key
                value: @values[hash]
                if value
                    delete @values[hash]
                    delete @keys[hash]
                    Mo.changed this, 'removed', { key: key, value: value, cause: e.cause }
        }
        
    get: -> [@keys[hash], value] for hash, value of @values

    values: -> value for hash, value of @values
        
    at: (key) -> @values[ihash key]
        
    reproduce: -> { type: 'added', key: @keys[hash], value: value } for hash, value of @values

   
class MappingValueSet
    constructor: (mapping) ->
        @mapping: mapping
        Mo.sub mapping, (e) -> Mo.changed this, e.type, { cause: e.cause, value: e.value }
        
    get: -> @mapping.values()
    
    reproduce: -> { type: 'added', value: value } for value in @mapping.values()


Mo: {
    
    filters: []
    
    sub: (observable, listener) ->
        if listener instanceof Function
            listener = { any: listener }
        throw "Invalid listener type"            unless listener instanceof Object
        observable.__listeners = []              unless observable.__listeners
        observable.__listeners.push(listener)
        for e in observable.reproduce()
            func: listener[e.type] || listener.any
            if func
                e.cause = 'subscribed'
                func(e)
        return observable

    unsub: (observable, listener) ->
        throw "Invalid listener type"            unless listener instanceof Object
        observable.__listeners = {}              unless observable.__listeners
        list: observable.__listeners
        if (index: list.indexOf listener) >= 0
            list.splice index, 1
        return observable
            
    changed: (observable, type, e) ->
        e.observable = observable
        e.type = type
        for func in Mo.filters
            if func(e) == false
                return
        return unless observable.__listeners?
        for listener in observable.__listeners
            func: listener[type] || listener.any
            if func?
                if func(e) == false
                    return
        undefined
                    
    addFilter: (func) ->
        Mo.filters.push func
    
    identify: (object) ->
        return "<undefined>" if not object?
        return "<null>" if object == null
        if object instanceof Object
            instanceName: if object.__instanceName? then " <${object.__instanceName}>" else ""
            "${object.constructor.name}_${ihash object}${instanceName}"
        else
            object.toString()
        
    startDumpingEvents: ->
        Mo.addFilter (e) ->
            message: "Mo ${Mo.identify e.observable} - ${e.type}"
            for prop, value of e
                if ['observable', 'type', 'cause'].indexOf(prop) == -1
                    message += " " + prop + "=" + Mo.identify(value)
            if e.cause then message += " (cause: ${e.cause})"
            if puts?
                puts message
            else
                console.log message
                
    newValue: (initialValue, cause) -> new ObservableValue initialValue, cause
        
    newSet: (initialContent, cause) -> new ObservableSet initialContent, cause
        
    newMap: -> new ObservableMap()
        
    newList: (initialContent, cause) -> new ObservableList initialContent, cause
        
    newPropertyValue: (value, prop) ->
        result: Mo.newValue()
        result.__instanceName = "property ${prop} of ${Mo.identify value}"
        Mo.sub value, (e) ->
            result.set((if e.value is null then null else e.value[prop]), e.cause)
        return result
        
    delegate: (delegatedValue, delegate, prop) ->
        delegate: Mo.newPropertyValue(delegate, prop) if prop?
        
        delegatedValue.__instanceName = if prop? then "delegated to ${prop} of ${Mo.identify delegate}" else "delegated to ${Mo.identify delegate}"
        prevValue: null
        listener: (e) ->
            delegatedValue.replay e
        Mo.sub delegate, (e) ->
            if prevValue
                Mo.unsub prevValue, listener
            prevValue: e.value
            if prevValue
                Mo.sub prevValue, listener
            else
                delegatedValue.set null, e.cause
        return delegatedValue
        
    newDelegatedValue: (delegate, prop) -> Mo.delegate Mo.newValue(), delegate, prop
    newDelegatedSet:   (delegate, prop) -> Mo.delegate Mo.newSet(), delegate, prop
    newDelegatedMap:   (delegate, prop) -> Mo.delegate Mo.newMap(), delegate, prop
    newDelegatedList:  (delegate, prop) -> Mo.delegate Mo.newList(), delegate, prop
    
    newComputedMapping: (baseSet, factory) ->
        new ComputedMapping baseSet, factory
    
    newComputedSet: (baseSet, factory) ->
        Mo.valueSetOfMapping Mo.newComputedMapping baseSet, factory
        
    newSingleValueMapping: (baseValue, factory) ->
        result: Mo.newValue()
        result.__instanceName = "single-value mapping from ${Mo.identify baseValue}"
        Mo.sub baseValue, (e) ->
            result.set((if e.value == null then null else factory e.value), e.cause)
        return result
        
    newLookupValue: (map, key) ->
        result: Mo.newValue()
        result.__instanceName = "lookup of ${Mo.identify key} in ${Mo.identify map}"
        lastKey: null
        
        Mo.sub key, (e) ->
            lastKey: e.value
            result.set((if lastKey == null then null else map.at lastKey), e.cause)
            
        Mo.sub map, {
            added:   (e) -> result.set e.value if lastKey != null && e.key == lastKey
            changed: (e) -> result.set e.value if lastKey != null && e.key == lastKey
            removed: (e) -> result.set null    if lastKey != null && e.key == lastKey
        }
        
        return result
    
    valueSetOfMapping: (mapping) -> new MappingValueSet mapping
        
}

test: ->
    a: {
        name: 'a'
    }
    b: {
        name: 'b'
    }
    
    class Rendered
    
    Mo.startDumpingEvents()
    
    puts ""; puts "START TEST"
    
    s: Mo.newSet()
    Mo.sub s, {
        added: (e) ->
            puts "${e.value.name} added: ${e.cause}"
        removed: (e) ->
            puts "${e.value.name} removed: ${e.cause}"
    }
    
    r: Mo.newComputedMapping s, (el) ->
        new Rendered()
    
    s.add a, 'menu'
    s.add b, 'menu'
    s.remove a, 'drag'
    s.add a, 'drag'
    s.clear 'closing'

if puts?
    test()
else
    window.Mo = Mo
