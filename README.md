## Description

This is a rather simple multitrack player that maps datasets to General MIDI playback. It is my final project for the IDMT module at my university, and is probably bound to evolve to something more usable at some point.

## Installation

You need npm and Bower to install dependencies.
To install libraries: `npm install && bower install`

Note the soundfonts library contains a lot of MP3s and is quite heavy (~380Mb) so it may take a while to download, and this is why it wasn't included.

If you get an error from Bower telling you the soundfont package is invalid then clone it manually and the app should work (cd into `bower_components` then `git clone https://github.com/gleitz/midi-js-soundfonts.git`)

### Dependencies

* [MIDI.js](https://github.com/mudcube/MIDI.js) for MIDI playback
* [MIDI soundfonts library](https://github.com/gleitz/midi-js-soundfonts)
* [jQuery](http://jquery.com) for manipulating the DOM because I'm too lazy to deal with vanilla JS
* CoffeeScript and Sass (required for development only)

## Build

```
coffee --bare -c *.coffee
sass style.sass style.css
```

## Source of datasets

Death rates in US: http://wonder.cdc.gov

## License

Licensed under the [WTFPL](./LICENSE.md) version 2.