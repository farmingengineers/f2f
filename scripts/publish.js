var fs = require('fs');
//var ftp = require('jsftp')

var params = {
  repo:   process.argv[2],
  branch: process.argv[3],
  owner:  process.argv[4],
  giturl: process.argv[5],
  source: process.argv[6],
  build:  process.argv[7]
};
var ftpRoot = "/" + params.repo + "/" + params.branch;

var uploadFile = function(localFile, remoteFile) {
  console.log(localFile + " --> " + remoteFile);
};
var uploadDirectory = function(localDir, remoteDir) {
  fs.readdir(localDir, function(err, list) {
    if(err) {
      console.error(localDir + ": " + err);
    } else {
      list.forEach(function(file) {
        var localPath = localDir + "/" + file;
        var remotePath = remoteDir + "/" + file;
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
