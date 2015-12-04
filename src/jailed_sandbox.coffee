if !jailed?
  console.error("make sure to load jailed before the advanced markdown javascript sandbox")

esprima = require 'esprima'
_ = require 'lodash'
once = require 'once'

snippetsDefinition = (api) ->
  _.reduce api.snippets, ((acc, i, fname) ->
    "#{acc}\nvar #{fname} = #{i}"), ""

allRemotes = (api) ->
  (_.map (api.remote || {}), (api,key) -> "var #{key}=app.remote.#{key}").join ";"

defaultConfig = timeout: 1500

Sandbox = {
  run: (code, customApi = {}, config = {}) ->
    config = _.defaults config, defaultConfig
    snippets = snippetsDefinition customApi
    remotes = allRemotes customApi

    remoteApi = customApi.links
    snippetsApi = _.keys customApi.snippets

    apiArgs = (_.union remoteApi, snippetsApi).join ","

    code = """
      var runTests = function(#{apiArgs}){var start = null;\n#{code}};
      var start = function(app){ this.application=null;#{remotes};#{snippets};runTests(#{apiArgs});app.remote.__finished__()};
      start(application);
    """

    if esprima?
      try
        esprima.parse code
      catch e
        customApi.remote?.failed? e
        return

    connected = true
    customApi.remote = _.defaults customApi.remote || {}, {}
    disconnect = null
    customApi.remote["__finished__"] = () ->
      connected = false
      customApi.remote?.finished?()
      disconnect()

    runner = new jailed.DynamicPlugin code, customApi.remote
    disconnect = runner.disconnect.bind(runner)

    setTimeout (() ->
      if connected
        customApi.remote?.finished?()
        console.error "Sandbox timed out after #{config.timeout}ms!"
        runner.disconnect()
      ), config.timeout
    
    disconnect

  debug: (code, customApi, config) ->
    code = "debugger;\n#{code}\n //@ sourceURL=debug.js\n"
    Sandbox.run code, customApi, config

}

module.exports = Sandbox
