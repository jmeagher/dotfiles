
var commonLayout = function() { return {
  "Tweetbot" : w(cornerSize(mainScreen, "top-left", 0.3, 0.5)),
  "Flint"    : w(cornerSize(mainScreen, "bottom-left", 0.4, 0.5)),
  "Activity Monitor" : w(cornerSize(mainScreen, "top-right", 0.4, 0.3)),
};
}

// Title regex for finding my personal web browser window vs the work one
var pbr = /^.*(Facebook|@gmail.com).*$/;

// 1 monitor layout
var oneMonitorLayout = S.lay("oneMonitor", _.extend(commonLayout(), {
  "MacVim" : w(cornerOnly(mainScreen, "top-right")),
  "iTerm" : w(moveSize(mainScreen, 0.3, 0.3, 0.7, 0.7)),
  "Google Chrome" : byTitleRegex([{"r":pbr, "op":cornerSize(mainScreen, "bottom-right", 0.7, 0.7)}], cornerSize(mainScreen, "top-left", 0.7, 0.7)),
}));

var twoMonitorLayout = S.lay("twoMonitor", _.extend(commonLayout(), {
  "MacVim" : w(cornerOnly(thunderbolt, "top-right")),
  "iTerm" : w(cornerSize(thunderbolt, "bottom-right", 0.6, 0.6)),
  "Google Chrome" : byTitleRegex([{"r":pbr, "op":moveSize(mainScreen, 0.1, 0.1, 0.8, 0.8)}], cornerSize(thunderbolt, "top-left", 0.7, 0.7)),
}));

// Defaults
// S.def(2, twoMonitorLayout);
S.def(2, twoMonitorLayout);
S.def(1, oneMonitorLayout);

// Layout Operations
var twoMonitor = S.op("layout", { "name" : twoMonitorLayout });
var oneMonitor = S.op("layout", { "name" : oneMonitorLayout });

// var universalLayout = function() {
//   // Should probably make sure the resolutions match but w/e
//   S.log("SCREEN COUNT: "+S.screenCount());
//   //if (false || S.screenCount() === 2) {
//   //  twoMonitor.run();
//   //} else { // if (S.screenCount() === 1) {
//     oneMonitor.run();
//     //mainDisplayOnly.run();
//   //}
// };

var relaunch = S.operation("relaunch");

// Batch bind everything. Less typing.
S.bnda({

  // Layout Bindings
  "1:ctrl;cmd;alt" : function() { oneMonitor.run(); },
  "2:ctrl;cmd;alt" : function() { twoMonitor.run(); },
  "5:ctrl;cmd;alt" : relaunch,

  // Grid
  "esc:ctrl" : S.op("grid")

});


