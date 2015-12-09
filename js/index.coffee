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
        # Empty the current table
        track.find(".data").empty()

        # Take the first item and figure out the keys available
        # in this dataset. (normally all items will be the
        # same length/have the same properties).
        fields = _.keys(data[0])

        # For every field we have
        for fieldName in fields
            # For all items in data, this gets
            # the value of array items that have this field name
            values = _.pluck(data, fieldName)

            # create a <tr> (table row)
            tr = $("<tr>")

            # Add a header to that row
            # (th = table header, will be ignored when reading)
            tr.append "<th>#{fieldName}</th>"

            # For each value, wrap it in <td> tags (a cell)
            # and append the whole thing to our tr
            tr.append(_.map values, (item) ->
                return "<td>#{item}</td>")

            # add some data to this, while we have the values
            # eg the min/max possible value, this will be useful later
            # for mapping a value to a note

            # but first convert all to numeric
            values = _.map values, (item) ->
                return Number.parseInt item, 10

            tr.attr("data-max", _.max(values))
            tr.attr("data-min", _.min(values))

            # then add all this to the .data table
            track.find(".data").append(tr)

        #@todo: trigger setSkipValue again

setSkipValue = (skipValue, track) ->
    track.find(".data td.skip").remove() # reset skipped beats
    newCells = Array(skipValue + 1).join("""<td class="skip"></td>""")
    track.find(".data td").after(newCells)

addTrack = ->
    track = $("""
        <article class="track">
            <div class="controls">
                <label>
                    <span>Instrument</span>
                    <select name="instruments"></select>
                </label>

                <label>
                    <span>Dataset</span>
                    <select name="datasets"></select>
                </label>

                <label>
                    <span>Conversion</span>
                    <select name="transformation">
                        <option value="direct_to_midi">Direct to MIDI</option>
                    </select>
                </label>

                <label>
                    <span>Velocity</span>
                    <input type="range" min="0" max="127" value="127" name="velocity" />
                </label>

                <label>
                    <span>Skip</span>
                    <input type="range" min="0" max="6" value="0" name="skip" />
                </label>
            </div>
            <div class="data-holder">
                <table class="data"></table>
            </div>
        </article>""")

    track.appendTo $(".tracks")

    # if we already loaded the list of instruments somewhere else, copy it
    # if not then it will be added to the initial tracks usually
    if $("select[name='instruments']").length > 0
        track.find("select[name='instruments']").append instrumentList

    if $("select[name='datasets']").length > 0
        track.find("select[name='datasets']").append $("select[name='datasets']").first().html()
        track.find("select[name='datasets']").trigger("change") # load first one

    # we trigger a scroll event, to make sure the controls are re-positioned
    $(window).scroll()

### FUNCTIONS FOR PLAYBACK ###

# This will block/stop the execution inside play();
# because it's asynchronous we can read that value
# inside our play loop
stop = ->
    stopped = true
    $("#playpause span").attr("class", "icon icon-play3")

    # Clear the timer for the next beat
    if nextTimeout isnt null
        clearTimeout nextTimeout


###*
 * Starts the playback. This is a recursive function
 * that will call itself at every beat, and each time
 * will figure the current beat and send it to playBeat.
###
play = ->
    stopped = false

    # Changes the button icon to pause (two || characters)
    $("#playpause span").attr("class", "icon icon-pause2")

    # block playback if we're not done loading
    if isLoading
        return stop()

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
        rewind()
        stop()

rewind = ->
    currentBeat = 0
    $(window).scrollLeft(0)

###*
 * Plays all the notes of a given beat.
 * It goes through every track, and for each one,
 * finds the current data point, converts it to notes/chords,
 * and play it in a new channel with the given parameters (instrument,
 * velocity, etc.)
###
playBeat = (beat) ->
    channel = 0 # Start at channel 0
    cell = null

    # Remove the green check on previously played beat
    $(".currentBeat").removeClass("currentBeat")

    $(".track").each ->
        # Find the settings in the track
        instrumentName = $(this).find("select[name='instruments']").val()
        velocity = $(this).find("input[name='velocity']").val()
        velocity = Number.parseInt(velocity, 10)

        # beat = beat + channel # @todo: remove, for testing only
        dataLine = 1

        # find the cell we'll use
        # within the table (.data) then find
        # the nth <tr> (row) where n = dataLine (row of data we're using)
        # and within that row, the nth column (<td>) which is the
        # current beat
        cell = $(this).find(".data tr:eq(#{ dataLine }) td:eq(#{beat})")

        # Add a class to this cell to show it's currently playing
        cell.addClass("currentBeat")

        # Parse the value of the cell into a number
        noteValue = cell.text()
        noteValue = Number.parseInt(noteValue, 10)

        # @todo: modify that value into notes/chords

        ### Play the note using MIDI.js ###

        # Set the volume of that channel to the max
        # (note: this cannot actually be changed per channel due to a bug
        # in MIDI.js, see https://github.com/mudcube/MIDI.js/issues/46
        # so we set the first to 127 regardless)
        MIDI.setVolume channel, 127

        # Set the desired instrument to that channel
        MIDI.programChange channel, MIDI.GM.byName[instrumentName].number

        # Set the start/end of that note
        MIDI.noteOn channel, noteValue, velocity, 0
        MIDI.noteOff channel, noteValue, velocity, speed

        # Increment the channel number for the next track
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
        $(".controls").css "left", $(this).scrollLeft()

    # Start by loading up MIDI.js
    # with a correct plugin (+ a default instrument)
    MIDI.loadPlugin
        soundfontUrl: "bower_components/midi-js-soundfonts/FluidR3_GM/"
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
        $("select[name='instruments']").append items
        instrumentList = items.join("")
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
        $("select[name='datasets']").append items
        datasetList = items.join("")
        stopLoadingIndicator()
        $("select[name='datasets']").trigger("change") # load first one


    ###  Event handlers ###

    # Add a track when the + button is clicked
    $(".add-track").on "click", addTrack

    # Stop or start the track when the play/pause button is clicked
    $("#playpause").on "click", ->
        if stopped then play()
        else stop()

    $("#rewind").on "click", rewind

    # Load an instrument when the dropdown changes
    $(".tracks").on "change", "select[name='instruments']", ->
        loadInstrument $(this).val()

    # Load a dataset when the dropdown changes
    $(".tracks").on "change", "select[name='datasets']", ->
        loadDataset $(this).val(), $(this).parents(".track").first()

    # Change the number of beats to skip for a dataset
    $(".tracks").on "change", "input[name='skip']", ->
        setSkipValue(Number.parseInt($(this).val(), 10), $(this).parents(".track").first())

    # Modify the speed of the track (in the header)
    $("#speed").on "change", ->
        speed = Number.parseFloat $(this).val(), 10

    # Plays/pauses when the space bar is pressed
    $(window).keypress (e) ->
         if (e.keyCode == 0 || e.keyCode == 32)
            $("#playpause").click()

    # @todo implement mute
    #icomoons = volume-mute & volume-mute2