noflo = require "noflo"

exports["test simple FBP file"] = (test) ->
    fbpData = """
    'somefile.txt' -> SOURCE Read(Readfile) OUT -> In Display(Output)
    """

    noflo.graph.loadFBP fbpData, (graph) ->
        test.equal graph.edges.length, 1
        test.equal graph.initializers.length, 1
        test.equal graph.nodes.length, 2

        test.done()

exports["test more complicated FBP file"] = (test) ->
    fbpData = """
    '8003' -> LISTEN WebServer(HTTP/Server) REQUEST -> IN Profiler(HTTP/Profiler) OUT -> IN Authentication(HTTP/BasicAuth)
    Authentication() OUT -> IN GreetUser(HelloController) OUT -> IN WriteResponse(HTTP/WriteResponse) OUT -> IN Send(HTTP/SendResponse)
    'hello.jade' -> SOURCE ReadTemplate(ReadFile) OUT -> TEMPLATE Render(Template)
    GreetUser() DATA -> OPTIONS Render() OUT -> STRING WriteResponse()
    """

    noflo.graph.loadFBP fbpData, (graph) ->
        test.equal graph.edges.length, 8
        test.equal graph.initializers.length, 2
        test.equal graph.nodes.length, 8
        test.done()

exports["test strings with whitespace"] = (test) ->
    fbpData = """
    'foo Bar BAZ' -> IN Display(Output)
    """

    noflo.graph.loadFBP fbpData, (graph) ->
        test.equal graph.edges.length, 0
        test.equal graph.initializers.length, 1
        test.equal graph.initializers[0].from.data, "foo Bar BAZ"
        test.equal graph.nodes.length, 1
        test.done()

exports["test strings with comments"] = (test) ->
    fbpData = """
    # Do more
    'foo bar' -> IN Display(Output) # Do stuff
    """

    noflo.graph.loadFBP fbpData, (graph) ->
        test.equal graph.edges.length, 0
        test.equal graph.initializers.length, 1
        test.equal graph.initializers[0].from.data, "foo bar"
        test.equal graph.nodes.length, 1
        test.done()

exports["test invalid syntax"] = (test) ->
    fbpData = """
    'foo' -> Display(Output)
    """

    test.throws ->
        noflo.graph.loadFBP fbpData, (graph) ->

    test.done()
