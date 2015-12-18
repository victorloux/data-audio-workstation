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

###*
 * Re-maps a number from one range to another.
 * Equivalent to the map function in Arduino and Processing
###
mapTo = (value, inMin, inMax, outMin, outMax, capped = false) ->
    newVal = (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin

    if capped
        if newVal > outMax then newVal = outMax
        if newVal < outMin then newVal = outMin

    return newVal


###*
 * Starts and stops the loading indicator at the top, and set a 'lock'
 * variable that will prevent playback until things are loaded
###
startLoadingIndicator = ->
    isLoading = true
    $(".loaded-indicator").removeClass("loaded").text "Loading…"
    $('body').css('cursor', 'wait')

stopLoadingIndicator = ->
    isLoading = false
    $(".loaded-indicator").addClass("loaded").text "All loaded."
    $('body').css('cursor', 'default')


###*
 * Dynamically loads an instrument from the soundfont directory
 * @param  {string} instrumentName Name of the instrument as in the soundfont
###
loadInstrument = (instrumentName) ->
    MIDI.loadResource
        instrument: instrumentName
        onprogress: (state, progress) ->
            startLoadingIndicator()
            # console.log state, progress
        onsuccess: ->
            stopLoadingIndicator()

###*
 * Dynamically loads a dataset, and then fills a table in the current track
 * @param  {string} datasetName Name of the JSON dataset
 * @param  {DOMObject} track       Track <article> where the table should be added
###
loadDataset = (datasetName, track) ->
    $.getJSON "data/#{ datasetName }.json", (data) ->
        # Empty the current table
        track.find(".data").empty()

        # Take the first item and figure out the keys available
        # in this dataset. (normally all items will be the
        # same length/have the same properties).
        fields = _.keys(data[0])

        i = 0

        # For every field we have
        for fieldName in fields
            # For all items in data, this gets
            # the value of array items that have this field name
            values = _.pluck(data, fieldName)

            # create a <tr> (table row)
            tr = $("<tr>")

            # Add a header to that row
            # (th = table header, will be ignored when reading)
            tr.append "<th><span>#{fieldName}</span></th>"

            # For each value, wrap it in <td> tags (a cell)
            # and append the whole thing to our tr
            tr.append(_.map values, (item) ->
                return "<td><span>#{item}</span></td>")

            # add some data to this, while we have the values
            # eg the min/max possible value, this will be useful later
            # for mapping a value to a note

            # but first convert all to numeric
            values = _.map values, (item) ->
                return Number.parseFloat item, 10

            tr.attr("data-max", _.max(values))
            tr.attr("data-min", _.min(values))

            # Always highlight the 2nd (index 1) row
            if i == 1
                tr.find("th").addClass("currentRow")

            # then add all this to the .data table
            track.find(".data").append(tr)
            i++

        track.find("[name='skip']").trigger("change")


        #also recalculate the height of headers
        # (because they're positioned absolutely and not statically in CSS,
        # their height is not modified)
        # 190 (height of a track) divided by the number of headers
        headers = track.find('th')
        numberOfHeaders = headers.length
        headers.css({
            "height": (190 / numberOfHeaders) + "px"
            "line-height": (190 / numberOfHeaders) + "px"
        })

        # we trigger a scroll event, to make sure the controls are re-positioned
        $(window).scroll()

setSkipValue = (skipValue, track) ->
    track.find(".data td.skip").remove() # reset skipped beats
    newCells = Array(skipValue + 1).join("""<td class="skip"></td>""")
    track.find(".data td").after(newCells)
    track.find(".skip-numeric").text(skipValue)
    updateTotalBeatsCount()

setShiftValue = (shiftValue, track) ->
    # reset shifted beats
    track.find(".data td.shifted-positive").remove()
    track.find(".data-shifted-negative tr").each (i) ->
        $(this).find("td").insertAfter(track.find(".data tr:eq(#{i}) th"))
    track.find(".data-shifted-negative").empty()

    # if we shift positively, add new cells at the beginning to the row
    # these will work the same as skipped beats
    if shiftValue > 0
        newCells = Array(shiftValue + 1).join("""<td class="shifted-positive"></td>""")
        track.find(".data th").after(newCells)

    # if we shift negatively, then virtually delete these beats
    else if shiftValue < 0
        # find the n first cells in each row, for this
        # slice the selection; and abs() because shiftValue is negative
        # then move them to the .data table
        track.find(".data tr").each (i) ->
            cells = $(this).find("td").slice(0, Math.abs(shiftValue))
            track.find(".data-shifted-negative").append("<tr>")
            cells.appendTo(track.find(".data-shifted-negative tr").filter(":last"))

    # update the numeric counter (easier to see than the range slider)
    if shiftValue > 0 then shiftValue = "+" + shiftValue # add a + if >0
    track.find(".shift-numeric").text(shiftValue)

    updateTotalBeatsCount()

addTrack = ->
    track = $("""
        <article class="track">
            <div class="controls">
                <a href="#" class="delete"><span class="icon icon-bin"></span></a>
                <select name="datasets"></select>

                <label>
                    <span>Instrument</span>
                    <select name="instruments"></select>
                </label>

                <label>
                    <span>Conversion</span>
                    <select name="conversion">
                        <option value="chord">Chord conversion</option>
                        <option value="scale">Map on a scale</option>
                        <option value="map_value">Map to note</option>
                        <option value="direct_to_midi">Direct to MIDI</option>
                    </select>
                </label>

                <label>
                    <span>Velocity</span>
                    <input type="range" min="0" max="127" value="127" name="velocity" />
                </label>

                <label>
                    <span>Skip beats (<em class="skip-numeric">0</em>)</span>
                    <input type="range" min="0" max="6" value="0" name="skip" />
                </label>

                <label>
                    <span>Shift beats (<em class="shift-numeric">0</em>)</span>
                    <input type="range" min="-8" max="8" value="0" name="shift" />
                </label>
            </div>
            <div class="data-holder">
                <table class="data-shifted-negative"></table>
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
    updateTotalBeatsCount()

### FUNCTIONS FOR PLAYBACK ###

# This will block/stop the execution inside play();
# because it's asynchronous we can read that value
# inside our play loop
stop = ->
    stopped = true
    $("#playpause span").attr("class", "icon icon-play2")

    # Clear the timer for the next beat
    if nextTimeout isnt null
        clearTimeout nextTimeout


###*
 * Starts the playback. This is a recursive function
 * that will call itself at every beat, and each time
 * will figure the current beat and send it to playBeat.
###
play = ->
    if stopped && currentBeat >= totalBeats
        rewind()

    stopped = false

    # Changes the button icon to pause
    $("#playpause span").attr("class", "icon icon-pause")

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
    nextTimeout = setTimeout(play, speed * 1000)

    # We move onto the next beat, for the next iteration...
    currentBeat++

    # ..but if that reaches the end of the 'song', then rewind and stop
    if currentBeat + 1 > totalBeats
        rewind()

###*
 * Puts the playhead back to zero and scroll back there
###
rewind = ->
    currentBeat = 0
    updateBeatCounter()
    $(window).scrollLeft(0)

    # Clears the markers
    $(".currentBeat").removeClass("currentBeat")


###*
 * Checks the length of all tracks and picks the shortest
 * This will be when the playhead stops, because otherwise
 * we'll miss notes
###
updateTotalBeatsCount = ->
    lengths = []

    # for each row
    $('tr').each ->
        # find the number of cells, and push it in the array
        lengths.push $(this).find('td').length

    # Update the total beats length
    totalBeats = _.min(lengths)

    # This should be re-triggered at the same time the beat
    # counts change
    recalculateTracksWidth()
    updateBeatCounter()


###*
 * Updates the beat counter at the top
###
updateBeatCounter = ->
    $(".beats").text("#{ currentBeat + 1 } / #{ totalBeats }")

# Resize the width of tracks div
# so that the background is long enough to fill it
# (otherwise it remains = to the page's length)
recalculateTracksWidth = ->
    widths = []
    $('.data').each ->
        widths.push $(this).width()

    # add the current window width to the list,
    # in case we have shorter datasets
    widths.push $(window).width()

    # resize the track and add some margin (for the headers)
    $('.tracks').width(_.max(widths)) + 120


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
    updateBeatCounter()

    # Remove the green check on previously played beat
    $(".currentBeat").removeClass("currentBeat")

    $(".track").each ->
        # Find the settings in the track
        instrumentName = $(this).find("select[name='instruments']").val()
        velocity = $(this).find("input[name='velocity']").val()
        velocity = Number.parseInt(velocity, 10)

        conversionType = $(this).find("select[name='conversion']").val()

        # Figure out which line of the dataset we will be using
        # for this we need to find the index of .currentRow out of all <td>
        # dataline will be the 0-based index of the row to use
        allFields = $(this).find("th")
        selectedField = allFields.filter(".currentRow")
        dataLine = allFields.index(selectedField)

        #keep a reference to the previous cell (for positioning purposes)
        previousCell = cell

        # find the cell we'll use
        # within the table (.data) then find
        # the nth <tr> (row) where n = dataLine (row of data we're using)
        # and within that row, the nth column (<td>) which is the
        # current beat
        cell = $(this).find(".data tr:eq(#{ dataLine }) td:eq(#{beat})")

        # if the cell does not exist (shorter dataset)
        if cell.length == 0
            cell = previousCell
            return

        # Add a class to this cell to show it's currently playing
        cell.addClass("currentBeat")

        # If this cell is being skipped or shifted then don't try to play it
        if cell.hasClass("skip") or cell.hasClass("shifted-positive")
            return

        # Parse the value of the cell into a number
        value = cell.text()
        value = Number.parseFloat(value, 10)
        chordValue = convertValueToNote(value, conversionType, cell.parent('tr'))

        # Re-convert to an integer
        chordValue = _.map chordValue, Math.round

        ### Play the note using MIDI.js ###

        # Set the volume of that channel to the max
        # (note: this cannot actually be changed per channel due to a bug
        # in MIDI.js, see https://github.com/mudcube/MIDI.js/issues/46
        # so we set the first to 127 regardless)
        MIDI.setVolume channel, 127

        # Set the desired instrument to that channel
        MIDI.programChange channel, MIDI.GM.byName[instrumentName].number

        # Set the start/end of that note
        # MIDI.noteOn channel, noteValue, velocity, 0
        MIDI.chordOn channel, chordValue, velocity, 0
        MIDI.chordOff channel, chordValue, velocity, speed

        # Increment the channel number for the next track
        channel++

    # When we're done with all the tracks
    # Use the Y position of the last cell selected
    # and scroll there, to keep the view in line the playhead
    cellPosition = cell.position().left

    # Math.max(0, …) to ensure we don't get a negative value if we're too far left
    # we take the position of the cell, plus half the width of the screen
    $(window).scrollLeft(Math.max(0, cellPosition - $(window).width() / 2))

# MIDI notes (starting on octave 4; there's 12 notes per octave
# so we add/remove multiples of 12 to add/remove an octave, from octave 0 to 10)
notes = {
    C:  48
    Cs: 49
    D:  50
    Ds: 51
    E:  52
    F:  53
    Fs: 54
    G:  55
    Gs: 56
    A:  57
    As: 58
    B:  59
}

convertValueToNote = (value, conversionType, trContext) ->
    # Get the domain (min, max) of the data for certain conversions, as we will mainly
    # want to show the difference between the lower and higher points
    # This gives us a base reference for pitch, velocity etc.
    min = Number.parseFloat trContext.data("min"), 10
    max = Number.parseFloat trContext.data("max"), 10

    # avoid a bug where nothing plays if all values are the same
    # (e.g. the metronome "dataset")
    if min == max
        max = max + 1

    switch conversionType
        when 'chord'

            chords = [
                [ notes['C'], notes['E'], notes['G'] ]
                [ notes['D'], notes['Fs'], notes['A'] ]
                [ notes['E'], notes['Gs'], notes['B'] ]
                [ notes['F'], notes['A'], notes['C'] ]
                [ notes['G'], notes['B'], notes['D'] ]
                [ notes['A'], notes['Cs'], notes['E'] ]
                [ notes['As'], notes['C'], notes['E'] ]
                [ (notes['C'] + 12), (notes['E'] + 12), (notes['G'] + 12) ]
            ]
            octave = mapTo(value, min, max, -1, 3, true) | 0
            chordNum = mapTo(value, min, max, 0, chords.length, true) | 0
            chordToUse = chords[chordNum]
            chordToUse = _.map chordToUse, (n) -> n + (octave * 12)
            return chordToUse

        when 'scale'
            # Mysolidian scale
            scale = [
                notes['C']
                notes['D']
                notes['E']
                notes['F']
                notes['G']
                notes['A']
                notes['As']
                notes['C']
            ]
            octave = mapTo(value, min, max, -2, 2, true) | 0 #((value / scale.length | 0) % 10)
            normalisedValue = mapTo(value, min, max, 0, scale.length, true) | 0
            note = scale[normalisedValue] + (octave * 12)
            return [ note ]

        when 'map_value'
            # Maps a value from C4 to B1
            return [ mapTo(value, min, max, 60, 83, true) ]

        when 'direct_to_midi'
            # directly return our value
            return [value]

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
        # same for the headings of tables
        $(".controls, .data th").css "left", $(this).scrollLeft()

    $(window).resize recalculateTracksWidth

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
        instrumentList = items.join("")
        $("select[name='instruments']").append instrumentList
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
        datasetList = items.join("")
        $("select[name='datasets']").append datasetList
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
    # Change the number of beats to skip for a dataset
    $(".tracks").on "change", "input[name='shift']", ->
        setShiftValue(Number.parseInt($(this).val(), 10), $(this).parents(".track").first())

    # Removes a track
    $(".tracks").on "click", ".delete", (e) ->
        e.preventDefault()

        if confirm("Do you really want to delete this track?")
            $(this).parents(".track").remove()
            recalculateTracksWidth()
            updateTotalBeatsCount()

    # Modify the speed of the track (in the header)
    $("#speed").on "change", ->
        speed = Number.parseFloat $(this).val(), 10

    # Plays/pauses when the space bar is pressed
    $(window).keypress (e) ->
         if (e.keyCode == 0 || e.keyCode == 32)
            $("#playpause").click()

    # Changes the active row in a dataset
    $(".tracks").on "click", "th", ->
        $(this).parents(".data").find("th.currentRow").removeClass("currentRow")
        $(this).addClass("currentRow")

