assert = require('./modules/logging/assert')
RenderingContainer = require('./rendering_container/rendering_container')
Page = require('./rendering_container/page')
InteractivePage = require('./rendering_container/interactive_page')
Renderer = require('./rendering/renderer')
View = require('./rendering/view')
EventEmitter = require('wolfy87-eventemitter')
config = require('./configuration/config')
dom = require('./interaction/dom')
designCache = require('./design/design_cache')
ComponentTree = require('./component_tree/component_tree')
Dependencies = require('./rendering/dependencies')
FieldExtractor = require('./component_tree/field_extractor')
MetadataConfig = require('./configuration/metadata_config')

module.exports = class Livingdoc extends EventEmitter

  # Create a new livingdoc in a synchronous way.
  # The design must be loaded first.
  #
  # Call Options:
  # - new({ data })
  #   Load a livingdoc with JSON data
  #
  # - new({ designName, designVersion })
  #   This will create a new empty livingdoc with your
  #   specified design name and version
  #
  # - new({ componentTree })
  #   This will create a new livingdoc from a
  #   componentTree
  #
  # @param data { json string } Serialized Livingdoc
  # @param designName { string } name of a design
  # @param designVersion { string } version of a design
  # @param componentTree { ComponentTree } A componentTree instance
  # @returns { Livingdoc object }
  @create: ({ data, designName, designVersion, layoutName, componentTree }) ->
    componentTree = if data?
      designName = data.design?.name
      designVersion = data.design?.version
      assert designName?, 'Error creating livingdoc: No design name is specified.'
      assert designVersion?, 'Error creating livingdoc: No design version is specified.'
      design = designCache.get(designName, designVersion)
      new ComponentTree(content: data, design: design)
    else if designName? && designVersion?
      design = designCache.get(designName, designVersion)
      new ComponentTree(design: design)
    else if componentTree?
      componentTree
    else
      assert false, 'Insufficient parameters to livingdoc#create. Pass either data, design name and version or component tree'

    if data?.layout
      layoutName = data.layout

    new Livingdoc({ componentTree, layoutName })


  constructor: ({ @componentTree, @layoutName }) ->

    # @model is a legacy attribute and should be deleted ASAP
    @model = @componentTree

    @interactiveView = undefined
    @readOnlyViews = []

    @design = @componentTree.design
    @dependencies = new Dependencies({ @componentTree })

    @metadataConfig = new MetadataConfig(@design.metadata)
    @fieldExtractor = new FieldExtractor(@componentTree, @metadataConfig)

    @forwardComponentTreeEvents()


  # Get a drop target for an event
  getDropTarget: ({ event }) ->
    document = event.target.ownerDocument
    { clientX, clientY } = event
    elem = document.elementFromPoint(clientX, clientY)
    if elem?
      coords = { left: event.pageX, top: event.pageY }
      target = dom.dropTarget(elem, coords)


  forwardComponentTreeEvents: ->
    @componentTree.changed.add =>
      @emit 'change', arguments


  # Append the livingdoc to the DOM within an iframe.
  #
  # @param {Object}
  #   host {DOM Node, jQuery object or CSS selector string} Where to append the article in the document.
  #   interactive {Boolean} Whether the document is edtiable (default: false).
  #   loadResources {Boolean} Load Js and CSS files.
  #     Only disable this if you are sure you have loaded everything manually.
  #   wrapper {DOM Node, jQuery object}
  #   iframe {Boolean} Whether to render the livingdoc in an iframe (default: true).
  #
  # Example:
  # article.appendTo({ host: '.article', interactive: true, loadResources: false })
  createView: ({ host, interactive, loadResources, wrapper, layoutName, iframe }) ->
    $host = $(host)
    iframe ?= true

    $host.html('') # empty container
    viewWrapper = @getWrapper({ wrapper, layoutName })

    view = new View
      livingdoc: this
      parent: $host
      isInteractive: interactive
      loadResources: loadResources
      wrapper: viewWrapper

    @addView(view)
    view.create(renderInIframe: iframe)


  # Append the livingdoc to the DOM.
  #
  # @param {Object}
  #   host {DOM Node, jQuery object or CSS selector string} Where to append the article in the document.
  #   loadResources {Boolean} Load Js and CSS files.
  #     Only disable this if you are sure you have loaded everything manually.
  #   wrapper {DOM Node, jQuery object}
  #
  # Example:
  # article.appendTo({ host: '.article', interactive: true, loadResources: false })
  appendTo: (options = {}) ->
    options.iframe = false
    @createView(options)


  createComponent: ->
    @componentTree.createComponent.apply(@componentTree, arguments)


  getWrapper: ({ wrapper, layoutName }) ->
    if wrapper?
      return wrapper
    else
      layoutName ?= @layoutName
      return @design.getLayout(layoutName)?.wrapper


  addView: (view) ->
    if view.isInteractive
      assert not @interactiveView?,
        'Error creating interactive view: A Livingdoc can have only one interactive view'

      @interactiveView = view
      view.whenReady.then ({ iframe, renderer }) =>
        @componentTree.setMainView(view)
    else
      @readOnlyViews.push(view)


  addJsDependency: (obj) ->
    @dependencies.addJs(obj)


  addCssDependency: (obj) ->
    @dependencies.addCss(obj)


  hasDependencies: ->
    @dependencies?.hasJs() || @dependencies?.hasCss()


  toHtml: ({ excludeComponents }={}) ->
    new Renderer(
      componentTree: @componentTree
      renderingContainer: new RenderingContainer()
      excludeComponents: excludeComponents
    ).html()


  serialize: ->
    serialized = @componentTree.serialize()
    serialized['layout'] = @layoutName

    serialized


  toJson: (prettify) ->
    data = @serialize()
    if prettify?
      replacer = null
      indentation = 2
      JSON.stringify(data, replacer, indentation)
    else
      JSON.stringify(data)


  # Debug
  # -----

  # Print the ComponentTree.
  printModel: () ->
    @componentTree.print()


  Livingdoc.dom = dom


