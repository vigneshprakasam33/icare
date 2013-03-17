###
Itineraries
  people in the car: bool
  visibility: friends, friends of friends, public
  daily: think about it
###

# From https://google-developers.appspot.com/maps/customize_ae458c7692ac994187feb6f58834b6af.frame

###global $:false, google:false, I18n:false###

'use strict'

window.icare = window.icare || {}
icare = window.icare

getJSONRoute = (route) ->
  # TODO server side, basing on start location, end location and via waypoints
  # NOTE server side is limited to 2.500 requests per day. Are we sure?

  data =
    start_location: null
    end_location: null
    via_waypoints: []
    overview_path: []
    overview_polyline: null

  rleg = route.legs[0]
  data.start_location =
    'lat': rleg.start_location.lat()
    'lng': rleg.start_location.lng()
  data.end_location =
    'lat': rleg.end_location.lat()
    'lng': rleg.end_location.lng()

  for waypoint in rleg.via_waypoints
    data.via_waypoints.push [waypoint.lat(), waypoint.lng()]

  for point in route.overview_path
    data.overview_path.push [point.lat(), point.lng()]

  data.overview_polyline = route.overview_polyline.points

  data

wizardPrevStep = ->
  step = (Number) $('#new_itinerary').data 'step'
  return if step <= 1

  lastStep = (Number) $('#new_itinerary').data 'lastStep'

  $("#wizard-step-#{step}-content").fadeOut ->
    $('#wizard-next-step-button').prop('disabled', false).show()
    $('#new_itinerary_submit').prop('disabled', true).hide()

    $("#wizard-step-#{step}-title").addClass('hidden-phone').removeClass 'active'

    $("#new_itinerary").data 'step', --step
    $("#wizard-step-#{step}-title")
      .removeClass('done').removeClass('hidden-phone').addClass('active')
      .find('.icon-check').addClass('icon-check-empty').toggleClass('icon-check')

    $("#wizard-step-#{step}-content").fadeIn()
    if step is 1
      $("#wizard-prev-step-button").prop('disabled', true).hide()

wizardNextStep = ->
  # Run validations
  if $('#itinerary_route').val() is ''
    $('#error').text(I18n.t 'javascript.setup_route_first').show()
    return false

  valid = true
  $('#new_itinerary [data-validate]:input:visible').each ->
    settings = window.ClientSideValidations.forms[this.form.id]
    unless $(this).isValid(settings.validators)
      valid = false
    return
  return false unless valid

  step = (Number) $('#new_itinerary').data 'step'
  lastStep = (Number) $('#new_itinerary').data 'lastStep'

  if step is lastStep
    return false

  $("#wizard-step-#{step}-content").fadeOut ->
    $("#wizard-step-#{step}-title")
      .removeClass('active').addClass('done').addClass('hidden-phone')
      .find('.icon-check-empty').addClass('icon-check').toggleClass('icon-check-empty')
    $('#new_itinerary').data 'step', ++step
    if step is lastStep
      lastStepInit()
    $("#wizard-step-#{step}-title").removeClass('hidden-phone').addClass 'active'
    $("#wizard-step-#{step}-content").fadeIn ->
      $('#new_itinerary').enableClientSideValidations() # Enable validation for new fields
    if step > 1
      $("#wizard-prev-step-button").prop('disabled', false).show()
      if step is lastStep
        $('#wizard-next-step-button').prop('disabled', true).hide()
        $('#new_itinerary_submit').prop('disabled', false).show()

dateFieldToString = (field_id) ->
  values = $("select[id^=#{field_id}] option:selected")
  year = $("##{field_id}_1i").val()
  month = $("##{field_id}_2i").val().lpad 0, 2
  day = $("##{field_id}_3i").val().lpad 0, 2
  hour = $("##{field_id}_4i").val().lpad 0, 2
  minute = $("##{field_id}_5i").val().lpad 0, 2
  dateString = "#{year}-#{month}-#{day}T#{hour}:#{minute}:00"
  if I18n? then I18n.l('time.formats.long', dateString) else dateString

window.test = dateFieldToString

lastStepInit = ->
  # TODO handlebars template
  $('#itinerary-preview-title').text $('#itinerary_title').val()
  $('#itinerary-preview-description').text $('#itinerary_description').val()
  $('#itinerary-preview-vehicle').text $('#itinerary_vehicle option:selected').text()
  $('#itinerary-preview-smoking_allowed').text I18n.t("boolean.#{$('#itinerary_smoking_allowed').prop 'checked'}")
  $('#itinerary-preview-pets_allowed').text I18n.t("boolean.#{$('#itinerary_pets_allowed').prop 'checked'}")
  $('#itinerary-preview-pink').text I18n.t("boolean.#{$('#itinerary_pink').prop 'checked'}")
  $('#itinerary-preview-fuel_cost').text $("#itinerary_fuel_cost").val()
  $('#itinerary-preview-tolls').text $("#itinerary_tolls").val()
  $('#itinerary-preview-leave_date').text dateFieldToString('itinerary_leave_date')

  if $('#itinerary_round_trip').prop('checked')
    $('#itinerary-preview-round_trip').text I18n.t('boolean.true')
    $('#itinerary-preview-return_date').text dateFieldToString('itinerary_return_date')
    $('.itinerary-preview-return').show()
  else
    $('#itinerary-preview-round_trip').text I18n.t('boolean.false')
    $('.itinerary-preview-return').hide()

  route = window.icare.route
  url_builder = $('#itinerary-preview-image')
    .data('staticMapUrlBuilder')
    .replace("%{end_location}", "#{route.end_location.lat},#{route.end_location.lng}")
    .replace("%{start_location}", "#{route.start_location.lat},#{route.start_location.lng}")
    .replace("%{overview_polyline}", "#{route.overview_polyline}")
  $('#itinerary-preview-image').attr 'src', url_builder

setRoute = (dr, result) ->
  dr.setDirections result
  dr.setOptions
    polylineOptions:
      strokeColor: '#0000ff'
      strokeWeight: 5
      strokeOpacity: 0.45
  dr.map.fitBounds dr.directions.routes[0].bounds
  # dr.setOptions
  #  suppressMarkers: true

createRouteMapInit = (id) ->
  map = icare.initGoogleMaps id

  dr = new google.maps.DirectionsRenderer
    map: map
    draggable: true
    preserveViewport: true

  ds = new google.maps.DirectionsService()

  google.maps.event.addListener dr, 'directions_changed', ->
    route = dr.getDirections().routes[0]
    json_route = getJSONRoute route
    $('#from-helper').text route.legs[0].start_address
    $('#to-helper').text route.legs[0].end_address
    $('#itinerary_route').val JSON.stringify(json_route)
    $('#itinerary_itineraries_route_waypoints').val JSON.stringify(route.legs[0].via_waypoints)
    window.icare.route = json_route
    $('#new_itinerary_submit').prop 'disabled', false
    $('#distance').text route.legs[0].distance.text
    $('#duration').text route.legs[0].duration.text
    $('#copyrights').text route.copyrights
    $('#route-helper').show()
    $('#result').show()
    $('#itinerary_title').val "#{$("#itinerary_itineraries_route_from").val()} - #{$("#itinerary_itineraries_route_to").val()}".substr(0, 40).capitalize()
    route_km = (Number) route.legs[0].distance.value / 1000
    route_gasoline = route_km * (Number) $('#fuel-help').data('avg-consumption')
    $('#fuel-help-text').text $('#fuel-help').data('text').replace("{km}", route_km.toFixed(2)).replace("{est}", parseInt(route_gasoline, 10))
    $('#fuel-help').show()
    path = route.overview_path
    map.fitBounds(dr.directions.routes[0].bounds)

  # Get Route acts as submit
  $('input[type=text][id^=itinerary_itineraries_route]').on 'keypress', (e) ->
    if e and e.keyCode is 13
      e.preventDefault()
      $('#get-route').click()

  $('#get-route').on 'click', ->
    valid = true
    $('[data-validate][id^=itinerary_itineraries_route]:input:visible').each ->
      settings = window.ClientSideValidations.forms[this.form.id]
      valid = false unless $(this).isValid settings.validators
      return
    return unless valid
    $('#itineraries-spinner').show()
    $('#error').hide()
    $('#result').hide()
    $('#route-helper').hide()
    $('#copyrights').text ''
    $('#distance').text ''
    $('#duration').text ''
    ds.route
      origin: $('#itinerary_itineraries_route_from').val()
      destination: $('#itinerary_itineraries_route_to').val()
      travelMode: 'DRIVING' # $("#mode").val()
      avoidHighways: $('#itinerary_itineraries_route_avoid_highways').prop 'checked'
      avoidTolls: $('#itinerary_itineraries_route_avoid_tolls').prop 'checked'
      waypoints:
        try
          JSON.parse($('#itinerary_route').val()).via_waypoints.map (point) ->
            { location: new google.maps.LatLng(point[0], point[1]) }
        catch error
          []
    , (result, status) ->
      $('#itineraries-spinner').hide()
      if status is google.maps.DirectionsStatus.OK
        setRoute dr, result
      else
        switch status
          when 'NOT_FOUND'
            message = I18n.t 'javascript.not_found'
          when 'ZERO_RESULTS'
            message = I18n.t 'javascript.zero_results'
          else
            message = status
        $('#error').text(message).show()

  $('.share').click ->
    $(this).find('input').focus().select()

  # Set route if it's already available
  if $('#itinerary_itineraries_route_from').val() isnt '' && $('#itinerary_itineraries_route_to').val() isnt ''
    # TODO cache this object
    $('#get-route').click()


initItineraryNew = ->
  createRouteMapInit('#new-itinerary-map')
  $('#wizard-next-step-button').on 'click', wizardNextStep
  $('#wizard-prev-step-button').on 'click', wizardPrevStep
  $('input[name="itinerary[daily]"]').change ->
    if (Boolean) $(this).val() is 'true'
      $('#single').fadeOut ->
        $('#daily').fadeIn()
    else
      $('#daily').fadeOut ->
        $('#single').fadeIn()
  $('#itinerary_round_trip').change ->
    status = $(this).prop 'checked'
    $('select[id^="itinerary_return_date"]').prop 'disabled', !status

# jQuery Turbolinks
$ ->
  if $('#new_itinerary')[0]?
    initItineraryNew()