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


function moveOnly(theScreen, xpos, ypos) {
    return {
    "operations" : [ S.op("move", {
            "screen" : theScreen,
            "x" : xpos + "*screenSizeX + screenOriginX",
            "y" : ypos + "*screenSizeY + screenOriginY",
            "width"  : "windowSizeX",
            "height" : "windowSizeY"
        }) ],
    "ignore-fail" : true,
    "repeat" : true
};
}

function moveSize(theScreen, xpos, ypos, width, height) {
    return {
    "operations" : [ S.op("move", {
            "screen" : theScreen,
            "x" : xpos + "*screenSizeX + screenOriginX",
            "y" : ypos + "*screenSizeY + screenOriginY",
            "width"  : width + "*screenSizeX",
            "height" : height + "*screenSizeY",
        }) ],
    "ignore-fail" : true,
    "repeat" : true
};
}

function cornerOnly(theScreen, corner) {
    return {
    "operations" : [ S.op("corner", {
            "screen" : theScreen,
            "direction" : corner,
            "width"  : "windowSizeX",
            "height" : "windowSizeY"
        }) ],
    "ignore-fail" : true,
    "repeat" : true
};
}

function cornerSize(theScreen, corner, width, height) {
    return {
    "operations" : [ S.op("corner", {
            "screen" : theScreen,
            "direction" : corner,
            "width"  : width + "*screenSizeX",
            "height" : height + "*screenSizeY",
        }) ],
    "ignore-fail" : true,
    "repeat" : true
};
}

/*
 *
var genBrowserHash = function(regex) {
  return {
    "operations" : [function(windowObject) {
      var title = windowObject.title();
      if (title !== undefined && title.match(regex)) {
        windowObject.doOperation(tboltLLeft);
      } else {
        windowObject.doOperation(lapMain);
      }
    }],
    "ignore-fail" : true,
    "repeat" : true
  };
}

*/
// Log that we're done configuring
S.log("[SLATE] -------------- Finished Loading Config --------------");
