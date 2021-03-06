angular.module "dc.modalMagic", ["ui.bootstrap"]

angular.module "dc.modalMagic"
.factory "modalMagic", ["$injector", "$q", ($injector, $q)->

  class InterruptingCow
    constructor: (config)->
      @modalPromise = null

      @data = config.data or {}
      @templateUrl = config.templateUrl or throw new Error "need templateUrl"
      @isValid = config.isValid or (data)->
        return true
      @onSubmit = config.onSubmit or (data)->
        return true
      @$modal = $injector.get "$modal"

    # executes a functions passing data as param
    # @return promise, coerced from func output, or func output if it is a promise
    #   resolved if func is truthy
    #   rejected if func is falsey
    asPromise: (func, data)->
      promise = func data

      if promise and promise.then
        return promise

      else
        deferred = $q.defer()
        if promise
          deferred.resolve promise
        else
          deferred.reject promise
        return deferred.promise

    # open the modal as a promise
    # if it fails, reopen the modal FOREVER
    # @returns promise that is resolved with the modified data
    open: ->
      return @onlyOne()
      .then (results)=>
        @data = results
        return @data
      .catch (error)=>
        @modalPromise = null
        console.error "YOU CANNOT ESCAPE YOUR DESTINY", error
        return @open()

    # we dont want a million modals open, so if the modal
    # is currently open, just return the promise 
    onlyOne: ->
      if @modalPromise
        return @modalPromise

      # after submitting, validate the results
      # using the isValid function
      @modalPromise = @openModal()
      .catch =>
        # modal gone, possible that what we had originally is good?
        return @data
      .then (results)=>
        return @asPromise @isValid, results

      return @modalPromise
      .then (results)->
        @modalPromise = null
        return results
      .catch (error)->
        @modalPromise = null
        throw error

    # open the modal:
    # controller has a submit and close function
    # submit calls onSubmit
    # @return promise that resolves on successful onSubmit
    #   or fails in all other cases
    openModal: ->
      self = this

      modal = @$modal.open
        templateUrl: @templateUrl
        controller: ["$scope", "$modalInstance", ($scope, $modalInstance)->
          $scope.data = self.data
          $scope.submit = ->
            # merge scope variables from template into data
            submittedData = angular.copy self.data
            for key, value of submittedData
              if $scope.data[key] isnt undefined
                submittedData[key] = $scope.data[key]
            # submit the scope based on user function
            self.asPromise self.onSubmit, submittedData
            .then (results)->
              $modalInstance.close results
            .catch (error)->
              $modalInstance.dismiss "onSubmit failed:"+error
          $scope.close = ->
            $modalInstance.dismiss "closed"

        ] # end controller
      return modal.result

  # end InterruptingCow

  # there can be only one (per id/config)
  highlanders = {}

  return {
    # @return the iterrupter for the id/config
    get: (id, config)->
      if highlanders[id]
        return highlanders[id]

      highlanders[id] = new InterruptingCow config
      return highlanders[id]
  }

]