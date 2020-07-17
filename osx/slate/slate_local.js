
var commonLayout = function() { return {
  "Activity Monitor" : w(cornerSize(mainScreen, "top-right", 0.4, 0.3)),
  "Slack"            : w(cornerSize(mainScreen, "bottom-left", 0.7, 0.7)),
};
}

// Title regex for finding my personal web browser window vs the work one
var pbr = /^.*(Facebook|@gmail.com).*$/;

// 1 monitor layout
var oneMonitorLayout = S.lay("oneMonitor", _.extend(commonLayout(), {
  "MacVim"        : w(sideOnly(mainScreen, "right")),
  "iTerm2"        : w(moveSize(mainScreen, 0.3, 0.3, 0.7, 0.7)),
  "IntelliJ IDEA" : w(cornerSize(mainScreen, "top-right", 0.7, 0.7)),
  "Code"          : w(cornerSize(mainScreen, "top-right", 0.7, 0.7)),
  "Google Chrome" : byTitleRegex([
    {"r":pbr, "op":cornerSize(mainScreen, "bottom-right", 0.7, 0.7)}
    ], moveSize(mainScreen, 0.0, 0.09, 0.7, 0.7)),
}));

var twoMonitorLayout = S.lay("twoMonitor", _.extend(commonLayout(), {
  "MacVim"        : w(cornerOnly(horizontal, "top-left")),
  "iTerm2"        : w(cornerSize(horizontal, "bottom-right", 0.5, 0.6)),
  "IntelliJ IDEA" : w(cornerSize(horizontal, "top-right", 0.5, 0.9)),
  "Code"          : w(cornerSize(horizontal, "top-left", 0.5, 0.9)),
  "Google Chrome" : byTitleRegex([
    {"r":pbr, "op":cornerSize(monLaptop, "top-right", 0.6, 0.7)}
    ], cornerSize(horizontal, "top-right", 0.5, 0.7)),
}));

var twoMonitor2Layout = S.lay("twoMonitor2", _.extend(commonLayout(), {
  "MacVim"        : w(cornerOnly(mainScreen, "top-left")),
  "iTerm2"        : w(cornerSize(horizontal2, "bottom-left", 0.7, 0.8)),
  "IntelliJ IDEA" : w(cornerSize(mainScreen, "top-right", 0.9, 0.9)),
  "Code"          : w(cornerSize(mainScreen, "top-right", 0.9, 0.9)),
  "Google Chrome" : byTitleRegex([
    {"r":pbr, "op":cornerSize(horizontal2, "bottom-right", 0.6, 0.7)}
    ], cornerSize(horizontal2, "top-left", 0.8, 0.9)),
}));

// Defaults
S.def(2, twoMonitor2Layout);
S.def(1, oneMonitorLayout);

// Layout Operations
var twoMonitor = S.op("layout", { "name" : twoMonitorLayout });
var twoMonitor2 = S.op("layout", { "name" : twoMonitor2Layout });
var oneMonitor = S.op("layout", { "name" : oneMonitorLayout });

var relaunch = S.operation("relaunch");

// Batch bind everything. Less typing.
S.bnda({

  // Layout Bindings
  "1:ctrl;cmd;alt" : function() { oneMonitor.run(); },
  "2:ctrl;cmd;alt" : function() { twoMonitor.run(); },
  "3:ctrl;cmd;alt" : function() { twoMonitor2.run(); },
  "5:ctrl;cmd;alt" : relaunch,

});


