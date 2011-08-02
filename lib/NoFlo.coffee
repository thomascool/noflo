# The main NoFlo runner

internalSocket = require "./InternalSocket"
component = require "./Component"
port = require "./Port"
arrayport = require "./ArrayPort"
graph = require "./Graph"

class NoFlo
    processes: {}
    connections: []
    graph: null
    startupDate: null

    constructor: (graph) ->
        @processes = {}
        @graph = graph

        @startupDate = new Date()

        @graph.on "addNode", (node) =>
            @addNode node
        @graph.on "removeNode", (node) =>
            @removeNode node
        @graph.on "addEdge", (edge) =>
            @addEdge edge
        @graph.on "removeEdge", (edge) =>
            @removeEdge edge
        @graph.on "addInitial", (initializer) =>
            @addInitial initializer

    uptime: -> new Date() - @startupDate

    load: (component) ->
        if typeof component is "object"
            return component
        try
            implementation = require component
        catch error
            try
                implementation = require "../components/#{component}"
            catch localError
                # Throw the original error instead
                throw error
        implementation.getComponent()

    addNode: (node) ->
        return if @processes[node.id]

        process = {}

        if node.component
            process.component = @load node.component

        process.id = node.id

        if node.config and process.component.initialize
            process.component.initialize node.config

        @processes[process.id] = process

    removeNode: (node) ->
        return unless @processes[node.id]

        # TODO: Check for existing edges with this node

        delete @processes[node.id]

    getNode: (id) ->
        @processes[id]

    connectPort: (socket, process, port, inbound) ->
        if inbound
            socket.to =
                process: process
                port: port

            return process.component.inPorts[port].attach socket

        socket.from =
            process: process
            port: port
        process.component.outPorts[port].attach socket

    addEdge: (edge) ->
        socket = internalSocket.createSocket()
        logSocket = (message) ->
            console.error "#{edge.from.node}:#{socket.from.port} -> #{edge.to.node}:#{socket.to.port} #{message}"
        socket.on "connect", ->
            logSocket "CONN"
        socket.on "disconnect", ->
            logSocket "DISC"
        socket.on "data", (data) ->
            logSocket "DATA"

        from = @getNode edge.from.node
        unless from
            throw new Error "No process defined for outbound node #{edge.from.node}"
        to = @getNode edge.to.node
        unless to
            throw new Error "No process defined for inbound node #{edge.to.node}"

        @connectPort socket, from, edge.from.port, false
        @connectPort socket, to, edge.to.port, true

        @connections.push socket

    removeEdge: (edge) ->
        for connection,index in @connections
            if edge.to.node is connection.to.process.id and edge.to.port is connection.to.port
                connection.to.process.component.inPorts[connection.to.port].detach connection
            if edge.from.node
                if connection.from and edge.from.node is connection.from.process.id and edge.from.port is connection.from.port
                    connection.from.process.component.inPorts[connection.from.port].detach connection
                    
            @connections.splice index, 1

    addInitial: (initializer) ->
        socket = internalSocket.createSocket()
        logSocket = (message) ->
            console.error "DATA -> #{socket.to.process.id}:#{socket.to.port} #{message}"
        socket.on "connect", ->
            logSocket "CONN"
        socket.on "disconnect", ->
            logSocket "DISC"
        socket.on "data", (data) ->
            logSocket "DATA"
        to = @getNode initializer.to.node
        unless to
            throw new Error "No process defined for inbound node #{initializer.to.node}"
        @connectPort socket, to, initializer.to.port, true
        socket.connect()
        socket.send initializer.from.data
        socket.disconnect()

        @connections.push socket

exports.createNetwork = (graph) ->
    network = new NoFlo graph

    network.addNode node for node in graph.nodes
    network.addEdge edge for edge in graph.edges
    network.addInitial initializer for initializer in graph.initializers

    network

exports.loadFile = (file, success) ->
    graph.loadFile file, (net) ->
        success exports.createNetwork net

exports.saveFile = (graph, file, success) ->
    graph.save file, ->
        success file

exports.Component = component.Component
exports.Port = port.Port
exports.ArrayPort = arrayport.ArrayPort
exports.graph = graph

# Method for extending include paths for
# NoFlo components
exports.addComponentIncludePaths = (paths) ->
  for path in paths
    require.paths.unshift path
