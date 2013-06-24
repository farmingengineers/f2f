var fs = require('fs');
var path = require('path');
var Ftp = require('jsftp')

var params = {
  repo:   process.argv[2],
  branch: process.argv[3],
  owner:  process.argv[4],
  giturl: process.argv[5],
  source: process.argv[6],
  build:  process.argv[7]
};
var ftpConfig = {
  host: process.env.FTP_HOST,
  user: process.env.FTP_USER,
  pass: process.env.FTP_PASS
};
var ftpRoot = path.join("/", params.repo);

var remote = {
  _ftp: new Ftp(ftpConfig),

  _dirCallbacks: {},
  _createdDirs: {},
  mkDir: function(dirname, cb) {
    if(dirname == '/' || remote._createdDirs[dirname]) {
      cb(null);
    } else if(remote._dirCallbacks[dirname]) {
      remote._dirCallbacks[dirname].push(cb);
    } else {
      remote._dirCallbacks[dirname] = [cb];
      var cb2 = function(err) {
        var callbacks = remote._dirCallbacks[dirname];
        delete remote._dirCallbacks[dirname];
        callbacks.forEach(function(f) { f(err); });
      }
      remote.mkDir(path.dirname(dirname), function(err) {
        if(err) {
          cb2(err);
        } else {
          console.log('[ftp] mkdir ' + dirname);
          remote._ftp.raw.mkd(dirname, function(err, data) {
            remote._createdDirs[dirname] = 1;
            cb2(null);
          });
        }
      });
    }
  },

  put: function(localFile, remoteFile, cb) {
    remote.mkDir(path.dirname(remoteFile), function(err) {
      if(err) {
        cb(err);
      } else {
        fs.readFile(localFile, function(err, data) {
          if(err) {
            cb(err)
          } else {
            remote._ftp.put(remoteFile, data, cb);
          }
        });
      }
    });
  }
};

var started = 0;
var finished = 0;

var uploadFile = function(localFile, remoteFile) {
  started += 1;
  console.log("[" + started + "] " + localFile + " --> " + remoteFile);
  remote.put(localFile, remoteFile, function(err) {
    finished += 1;
    if(err) {
      console.error("[" + finished + "/" + started + "] " + remoteFile + ": " + err);
    } else {
      console.log("[" + finished + "/" + started + "] " + remoteFile + ": success");
    }
    if(remote.complete && finished == started) {
      remote._ftp.raw.quit();
    }
  });
};

var uploadDirectory = function(localDir, remoteDir) {
  fs.readdir(localDir, function(err, list) {
    if(err) {
      console.error(localDir + ": " + err);
    } else {
      list.forEach(function(file) {
        var localPath = path.join(localDir, file);
        var remotePath = path.join(remoteDir, file);
        fs.stat(localPath, function(err, stat) {
          if(err) {
            console.error(localPath + ": " + err);
          } else {
            if(stat.isDirectory()) {
              uploadDirectory(localPath, remotePath);
            } else {
              uploadFile(localPath, remotePath);
            }
          }
        });
      });
    }
  });
};
uploadDirectory(params.build, ftpRoot);
remote.complete = true;
