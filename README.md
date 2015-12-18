## Description

This is a rather simple DAW-like interface that maps data to tracks that can be played with General MIDI. It is my final project for the IDMT module at my university, and is probably bound to evolve to something more usable at some point.

## Installation

You'll need npm and Bower to install dependencies. To do this:

```
git clone https://github.com/gleitz/midi-js-soundfonts.git
npm install
bower install
```

Note the soundfonts library contains a lot of MP3s and is quite heavy (~380Mb) so it may take a while to download.

### Dependencies

* [MIDI.js](https://github.com/mudcube/MIDI.js) for MIDI playback
* [MIDI soundfonts library](https://github.com/gleitz/midi-js-soundfonts)
* [jQuery](http://jquery.com) for manipulating the DOM because I'm too lazy to deal with vanilla JS
* [underscore.js](http://underscorejs.org) for easily working with data
* [icomoon](http://icomoon.io) for quick interface prototyping
* CoffeeScript and Sass (required for development only)

## Build

```
coffee --bare -c js/index.coffee
sass css/style.sass css/style.css
```

## Source of datasets

* Death rates in US: http://wonder.cdc.gov
* Magarine consumption in US: Department of Agriculture; Economic Research Service
* Worldwide vegetable production: FAO
* Doctorates awarded in the US: http://www.nsf.gov/statistics/infbrief/nsf11305/
* Unemployment rates in UK: IMF
* Population growth in UK: World Bank
* National debt of the UK: Office for National Statistics
* English voters for Scottish Independence: NatCen, 2013
* Evolution of vote on Scottish independence: WhatScotlandThinks.org
* A-level results: http://www.bstubbs.co.uk/a-lev.htm


## License

Licensed under the [WTFPL](./LICENSE.md) version 2.