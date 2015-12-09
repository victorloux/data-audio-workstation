// Generated by CoffeeScript 1.7.1

/*
 * Victor Loux <v.loux@qmul.ac.uk
 */

/* UTILITY FUNCTION & VARIABLES */
var addTrack, currentBeat, datasetList, instrumentList, isLoading, loadDataset, loadInstrument, makeRange, nextTimeout, play, playBeat, speed, startLoadingIndicator, stop, stopLoadingIndicator, stopped, totalBeats, velocity;

isLoading = true;

stopped = true;

nextTimeout = null;

currentBeat = 0;

totalBeats = 29;

speed = 1 / 4;

velocity = 127;

instrumentList = datasetList = null;

startLoadingIndicator = function() {
  isLoading = true;
  return $(".loaded-indicator").removeClass("loaded").text("Loading…");
};

stopLoadingIndicator = function() {
  isLoading = false;
  return $(".loaded-indicator").addClass("loaded").text("All loaded.");
};

makeRange = function(start, stop, step) {
  var length, range;
  if (step == null) {
    step = 1;
  }
  if (stop === null) {
    stop = start || 0;
    start = 0;
  }
  length = Math.max(Math.ceil((stop - start) / step), 0);
  range = Array(length);
  for (var idx = 0; idx < length; idx++, start += step) {
      range[idx] = start;
    };
  return range;
};

loadInstrument = function(instrumentName) {
  return MIDI.loadResource({
    instrument: instrumentName,
    onprogress: function(state, progress) {
      return startLoadingIndicator();
    },
    onsuccess: function() {
      return stopLoadingIndicator();
    }
  });
};

loadDataset = function(datasetName, track) {
  return $.getJSON("data/" + datasetName + ".json", function(data) {
    var lines;
    track.find('.data').empty();
    lines = [[], []];
    $.each(data, function(key, val) {
      lines[0].push("<td>" + key + "</td>");
      return lines[1].push("<td>" + val + "</td>");
    });
    track.find('.data').append($('<tr>').append(lines[0]));
    return track.find('.data').append($('<tr>').append(lines[1]));
  });
};

addTrack = function() {
  var track;
  track = $("<article class=\"track\">\n    <div class=\"controls\">\n        <label>Instrument <select class=\"instruments\"></select></label>\n        <label>Dataset <select class=\"datasets\"></select></label>\n        <label>Transformation <select class=\"transformation\">\n            <option value=\"direct_to_midi\">Direct to MIDI</option>\n        </select></label>\n        <label>Velocity\n            <input type=\"range\" min=\"0\" max=\"127\" value=\"127\" class=\"velocity\" />\n        </label>\n    </div>\n    <div class=\"data-holder\">\n        <table class=\"data\"></table>\n    </div>\n</article>");
  track.appendTo($(".tracks"));
  if ($('.instruments').length > 0) {
    track.find('.instruments').append(instrumentList);
  }
  if ($('.datasets').length > 0) {
    track.find('.datasets').append($('.datasets').first().html());
    track.find('.datasets').trigger("change");
  }
  return $(window).scroll();
};


/* FUNCTIONS FOR PLAYBACK */

stop = function() {
  stopped = true;
  $('#playpause').text('\u25B6');
  if (nextTimeout !== null) {
    return clearTimeout(nextTimeout);
  }
};

play = function() {
  stopped = false;
  $('#playpause').text('\u2759\u2759');
  if (isLoading) {
    return stop();
  }
  MIDI.setVolume(0, 127);
  playBeat(currentBeat);
  nextTimeout = setTimeout(play, speed * 1000 * 2);
  currentBeat++;
  if (currentBeat >= totalBeats) {
    currentBeat = 0;
    return stop();
  }
};

playBeat = function(beat) {
  var cell, cellPosition, channel;
  channel = 0;
  cell = null;
  $(".currentBeat").removeClass("currentBeat");
  $('.track').each(function() {
    var dataLine, instrumentName, noteValue;
    instrumentName = $(this).find('.instruments').val();
    velocity = $(this).find('.velocity').val();
    velocity = Number.parseInt(velocity, 10);
    beat = beat + channel;
    dataLine = 1;
    cell = $(this).find(".data tr:eq(" + dataLine + ") td:eq(" + beat + ")");
    cell.addClass('currentBeat');
    noteValue = cell.text();
    noteValue = Number.parseInt(noteValue, 10);
    MIDI.programChange(channel, MIDI.GM.byName[instrumentName].number);
    MIDI.noteOn(channel, noteValue, velocity, 0);
    MIDI.noteOff(channel, noteValue, velocity, speed);
    return channel++;
  });
  cellPosition = cell.position().left;
  return $(window).scrollLeft(Math.max(0, cellPosition - $(window).width() / 2));
};

$(function() {
  startLoadingIndicator();
  addTrack();
  $(window).scroll(function() {
    return $('.controls').css("left", $(this).scrollLeft());
  });
  MIDI.loadPlugin({
    soundfontUrl: "bower_components/MIDI.js Soundfonts/FluidR3_GM/",
    instrument: "acoustic_grand_piano",
    onprogress: function(state, progress) {},
    onsuccess: function() {
      return stopLoadingIndicator();
    }
  });
  $.getJSON("instruments.json", function(data) {
    var items;
    items = [];
    $.each(data, function(groupName, instrArray) {
      items.push("<optgroup label=\"" + groupName + "\">");
      $.each(instrArray, function(instrCode, instrName) {
        return items.push("<option value=\"" + instrCode + "\">" + instrName + "</option>");
      });
      return items.push("</optgroup>");
    });
    $('.instruments').append(items);
    instrumentList = items.join('');
    return stopLoadingIndicator();
  });
  $.getJSON("datasets.json", function(data) {
    var items;
    items = [];
    $.each(data, function(groupName, setsArray) {
      items.push("<optgroup label=\"" + groupName + "\">");
      $.each(setsArray, function(datasetCode, datasetName) {
        return items.push("<option value=\"" + datasetCode + "\">" + datasetName + "</option>");
      });
      return items.push("</optgroup>");
    });
    $('.datasets').append(items);
    datasetList = items.join('');
    stopLoadingIndicator();
    return $(".datasets").trigger("change");
  });

  /*  Event handlers */
  $('.add-track').on("click", addTrack);
  $('#playpause').on("click", function() {
    if (stopped) {
      return play();
    } else {
      return stop();
    }
  });
  $(".tracks").on("change", ".instruments", function() {
    return loadInstrument($(this).val());
  });
  $(".tracks").on("change", ".datasets", function() {
    return loadDataset($(this).val(), $(this).parents('.track').first());
  });
  return $("#speed").on("change", function() {
    return speed = Number.parseFloat($(this).val(), 10);
  });
});