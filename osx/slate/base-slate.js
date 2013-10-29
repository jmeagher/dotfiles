// enable to see debug messages in Console.app
//$.debug = true;


// Configs
S.cfga({
  "defaultToCurrentScreen" : true,
  "secondsBetweenRepeat" : 0.1,
  "checkDefaultsOnLoad" : true,
  "focusCheckWidthMax" : 3000,
  "orderScreensLeftToRight" : true
});


var wrap = function(op) {
    return {
    "operations" : [ op ],
    "ignore-fail" : true,
    "repeat" : true
};
}

var w = wrap;

var moveOnly = function(theScreen, xpos, ypos) {
    return  S.op("move", {
            "screen" : theScreen,
            "x" : xpos + "*screenSizeX + screenOriginX",
            "y" : ypos + "*screenSizeY + screenOriginY",
            "width"  : "windowSizeX",
            "height" : "windowSizeY"
        });
}

var moveSize = function(theScreen, xpos, ypos, width, height) {
    return S.op("move", {
            "screen" : theScreen,
            "x" : xpos + "*screenSizeX + screenOriginX",
            "y" : ypos + "*screenSizeY + screenOriginY",
            "width"  : width + "*screenSizeX",
            "height" : height + "*screenSizeY",
        });
}

var cornerOnly = function(theScreen, corner) {
    return S.op("corner", {
            "screen" : theScreen,
            "direction" : corner,
            "width"  : "windowSizeX",
            "height" : "windowSizeY"
        });
}

var cornerSize = function(theScreen, corner, width, height) {
    return S.op("corner", {
            "screen" : theScreen,
            "direction" : corner,
            "width"  : width + "*screenSizeX",
            "height" : height + "*screenSizeY",
        });
}

/*
 * Example: byTitleRegex([{"r":/^Inbox.*$/, "op":cornerOnly(main,"top-left")}], cornerOnly(main,"top-right"))
 * The first matching expression will be used
 */
var byTitleRegex = function(actionPairs, defaultOperation) {
  return {
    "operations" : [ function(windowObject) {
      var title = windowObject.title();
      var operation = defaultOperation;

      if (title !== undefined)
      {
          var matched = _.find(actionPairs, function(it) { return title.match(it["r"]); });
          if (matched) {
             operation = matched["op"];
          }
      }
      
      windowObject.doOperation(operation);

    } ],
    "ignore-fail" : true,
    "repeat" : true
  };
}


