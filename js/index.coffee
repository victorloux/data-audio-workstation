###
# Victor Loux <v.loux@qmul.ac.uk
###


### UTILITY FUNCTION & VARIABLES ###

# Status
isLoading = true
stopped = true
nextTimeout = null

# Tracks the current position
currentBeat = 0
totalBeats = 29
speed = 1/4
velocity = 127

# This will hold our list of instruments & datasets
instrumentList = datasetList = null

startLoadingIndicator = ->
    isLoading = true
    $(".loaded-indicator").removeClass("loaded").text "Loading…"

stopLoadingIndicator = ->
    isLoading = false
    $(".loaded-indicator").addClass("loaded").text "All loaded."

makeRange = (start, stop, step = 1) ->
    if (stop == null)
      stop = start || 0
      start = 0

    length = Math.max(Math.ceil((stop - start) / step), 0)
    range = Array(length)

    `for (var idx = 0; idx < length; idx++, start += step) {
      range[idx] = start;
    }`

    return range

loadInstrument = (instrumentName) ->
    MIDI.loadResource
        instrument: instrumentName
        onprogress: (state, progress) ->
            startLoadingIndicator()
            # console.log state, progress
        onsuccess: ->
            stopLoadingIndicator()

loadDataset = (datasetName, track) ->
    $.getJSON "data/#{ datasetName }.json", (data) ->
        track.find('.data').empty()

        lines = [[], []]
        $.each data, (key, val) ->
            lines[0].push "<td>#{ key }</td>"
            lines[1].push "<td>#{ val }</td>"

        track.find('.data').append($('<tr>').append(lines[0]))
        track.find('.data').append($('<tr>').append(lines[1]))


addTrack = ->
    track = $("""
        <article class="track">
            <div class="controls">
                <label>Instrument <select class="instruments"></select></label>
                <label>Dataset <select class="datasets"></select></label>
                <label>Transformation <select class="transformation">
                    <option value="direct_to_midi">Direct to MIDI</option>
                </select></label>
                <label>Velocity
                    <input type="range" min="0" max="127" value="127" class="velocity" />
                </label>
            </div>
            <div class="data-holder">
                <table class="data"></table>
            </div>
        </article>""")

    track.appendTo $(".tracks")

    # if we already loaded the list of instruments somewhere else, copy it
    # if not then it will be added to the initial tracks usually
    if $('.instruments').length > 0
        track.find('.instruments').append instrumentList

    if $('.datasets').length > 0
        track.find('.datasets').append $('.datasets').first().html()
        track.find('.datasets').trigger("change") # load first one

    # we trigger a scroll event, to make sure the controls are re-positioned
    $(window).scroll()

### FUNCTIONS FOR PLAYBACK ###

# This will block/stop the execution inside play();
# because it's asynchronous we can read that value
# inside our play loop
stop = ->
    stopped = true
    $('#playpause').text('\u25B6')

    # Clear the timer for the next beat
    if nextTimeout isnt null
        clearTimeout nextTimeout

play = ->
    stopped = false
    $('#playpause').text('\u2759\u2759')

    # block playback if we're not done loading
    if isLoading
        return stop()

    MIDI.setVolume 0, 127

    # Play the current beat
    playBeat(currentBeat)

    # Call this function again in n milliseconds using a timer
    # the variable 'speed' is in second, we need ms so we multiply by 1000
    # and then x2 to have a delay
    #
    # We put that timer in the nextTimeout variable,
    # so that we can clear that timer to stop the playback
    nextTimeout = setTimeout(play, speed * 1000 * 2)

    # We move onto the next beat, for the next iteration...
    currentBeat++

    # ..but if that reaches the end of the 'song', then rewind and stop
    if currentBeat >= totalBeats
        currentBeat = 0
        stop()

playBeat = (beat) ->
    channel = 0 # Start at channel 0
    cell = null

    # Remove the green check on previously played beat
    $(".currentBeat").removeClass("currentBeat")

    $('.track').each ->
        # Find the settings in the track
        instrumentName = $(this).find('.instruments').val()
        velocity = $(this).find('.velocity').val()
        velocity = Number.parseInt(velocity, 10)

        beat = beat + channel #@todo: remove, for testing only
        dataLine = 1

        # find the cell we'll use
        cell = $(this).find(".data tr:eq(#{ dataLine }) td:eq(#{beat})")

        cell.addClass('currentBeat')

        noteValue = cell.text()
        noteValue = Number.parseInt(noteValue, 10)

        # Play the note
        MIDI.programChange channel, MIDI.GM.byName[instrumentName].number
        MIDI.noteOn channel, noteValue, velocity, 0
        MIDI.noteOff channel, noteValue, velocity, speed

        channel++

    # When we're done with all the tracks
    # Use the Y position of the last cell selected
    # and scroll there, to keep the view in line the playhead
    cellPosition = cell.position().left

    # Math.max(0, …) to ensure we don't get a negative value if we're too far left
    # we take the position of the cell, plus half the width of the screen
    $(window).scrollLeft(Math.max(0, cellPosition - $(window).width() / 2))



# On page load (this is equivalent to DOMContentLoaded for jQuery)
$ ->
    # Give an initial "loading...' message (defined in utils)
    startLoadingIndicator()

    # Add a first track
    addTrack()

    # When scrolling, this will keep the controls of the track to the left
    # (I don't use position:fixed in CSS because that keeps it fixed on
    # both axes, whereas I only need the X axis)
    $(window).scroll ->
        # its sets the 'left' css property to the current X scroll value
        $('.controls').css "left", $(this).scrollLeft()

    # Start by loading up MIDI.js
    # with a correct plugin (+ a default instrument)
    MIDI.loadPlugin
        soundfontUrl: "bower_components/MIDI.js Soundfonts/FluidR3_GM/"
        instrument: "acoustic_grand_piano"
        onprogress: (state, progress) ->
            # console.log state, progress
        onsuccess: ->
            stopLoadingIndicator()

    # Loads the list of all possible instruments (it's in a separate JSON)
    $.getJSON "instruments.json", (data) ->
        # Callback: it is loaded, add each item to an <option> tag
        items = []
        $.each data, (groupName, instrArray) ->
            items.push """<optgroup label="#{ groupName }">"""

            $.each instrArray, (instrCode, instrName) ->
                items.push """<option value="#{ instrCode }">#{ instrName }</option>"""

            items.push """</optgroup>"""

        # then add these <option> tags to every <select> that's already in place
        # (if we add tracks later it will be copied from existing tracks)
        $('.instruments').append items
        instrumentList = items.join('')
        stopLoadingIndicator()


    # Loads the list of all possible datasets (in a separate JSON)
    $.getJSON "datasets.json", (data) ->
        # Callback: when this is loaded, add each item to an <option> tag
        items = []
        $.each data, (groupName, setsArray) ->
            items.push """<optgroup label="#{ groupName }">"""

            $.each setsArray, (datasetCode, datasetName) ->
                items.push """<option value="#{ datasetCode }">#{ datasetName }</option>"""

            items.push """</optgroup>"""

        # then add these <option> tags to every <select> that's already in place
        # (if we add tracks later it will be copied from existing tracks)
        $('.datasets').append items
        datasetList = items.join('')
        stopLoadingIndicator()
        $(".datasets").trigger("change") # load first one


    ###  Event handlers ###

    # Add a track when the + button is clicked
    $('.add-track').on "click", addTrack

    # Stop or start the track when the play/pause button is clicked
    $('#playpause').on "click", ->
        if stopped then play()
        else stop()

    # Load an instrument when the dropdown changes
    $(".tracks").on "change", ".instruments", ->
        loadInstrument $(this).val()

    # Load a dataset when the dropdown changes
    $(".tracks").on "change", ".datasets", ->
        loadDataset $(this).val(), $(this).parents('.track').first()

    # Modify the speed of the track (in the header)
    $("#speed").on "change", ->
        speed = Number.parseFloat $(this).val(), 10
