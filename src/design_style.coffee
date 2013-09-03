class DesignStyle

  constructor: ({ @name, @type, value, options }) ->
    if @type isnt 'option' && @type isnt 'select'
      log.error "TemplateStyle error: unknown type '#{ @type }'"

    if @type is 'option'
      @value = value
    else if @type is 'select'
      @options = options
    else
      log.error 'TemplateStyle error: no value or options provided'


  # Get instructions which css classes to add and remove.
  # We do not control the class attribute of a snippet DOM element
  # since the UI or other scripts can mess with it any time. So the
  # instructions are designed not to interfere with other css classes
  # present in an elements class attribute.
  cssClassChanges: (value) ->
    if @validateValue(value)
      if @type is 'option'
        remove: if value is undefined then [@value] else undefined
        add: value
      else if @type is 'select'
        remove: @otherClasses(value)
        add: value
    else
      if @type is 'option'
        remove: currentValue
        add: undefined
      else if @type is 'select'
        remove: @otherClasses(undefined)
        add: undefined


  validateValue: (value) ->
    if !value
      true
    else if @type is 'option'
      value == @value
    else if @type is 'select'
      @containsOption(value)
    else
      log.warn "Not implemented: DesignStyle#validateValue() for type #{ @type }"


  containsOption: (value) ->
    for option in @options
      return true if value is option.value

    false


  otherOptions: (value) ->
    others = []
    for option in @options
      others.push option if option.value isnt value

    others


  otherClasses: (value) ->
    others = []
    for option in @options
      others.push option.value if option.value isnt value

    others
