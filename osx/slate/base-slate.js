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


var monLaptop = "1680x1050";

/*
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

// 1 monitor layout
var oneMonitorLayout = S.lay("oneMonitor", {
  "Tweetbot" : cornerSize(monLaptop, "top-left", 0.3, 0.5),
  "Flint"    : cornerSize(monLaptop, "bottom-left", 0.4, 0.5),
  "MacVim" : cornerOnly(monLaptop, "top-right"),
  "iTerm" : moveSize(monLaptop, 0.3, 0.3, 0.7, 0.7)
});

var twoMonitorLayout = oneMonitorLayout;

// Defaults
S.def(2, twoMonitorLayout);
S.def(1, oneMonitorLayout);

// Layout Operations
var twoMonitor = S.op("layout", { "name" : twoMonitorLayout });
var oneMonitor = S.op("layout", { "name" : oneMonitorLayout });

var universalLayout = function() {
  // Should probably make sure the resolutions match but w/e
  S.log("SCREEN COUNT: "+S.screenCount());
  if (S.screenCount() === 2) {
    twoMonitor.run();
  } else if (S.screenCount() === 1) {
    oneMonitor.run();
    //mainDisplayOnly.run();
  }
};

// Batch bind everything. Less typing.
S.bnda({

  // Layout Bindings
  "1:ctrl;cmd;alt" : oneMonitor,
  // "2:ctrl" : universalLayout(),

  // Grid
  "esc:ctrl" : S.op("grid")


});

// Log that we're done configuring
S.log("[SLATE] -------------- Finished Loading Config --------------");
