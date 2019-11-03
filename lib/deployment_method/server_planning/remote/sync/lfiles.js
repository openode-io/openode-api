"use strict";

const fs = require("fs");
const childProc = require("child_process");

function computeChecksum(filePath) {
  try {
    const resultSha = childProc.execSync(`sha1sum "${filePath}"`).toString();
    const parts = resultSha.split(" ");
    const checksum = parts[0];

    return checksum;
  } catch(err) {
    console.error(err);
    return "";
  }
}

function filesListing(origDir, dir) {
  let allFiles = [];

  try {
    const files = fs.readdirSync(dir);

    for (let f of files) {
      let fInfo = {};
      fInfo.path = dir + "/" + f;
      let origPath = fInfo.path;

      const fStat = fs.statSync(fInfo.path);

      if ((f == "node_modules" && fStat.isDirectory()) ||
        (f == ".git" && fStat.isDirectory()) ||
        (f == "Dockerfile" && ! fStat.isDirectory()) ||
        (f == "openode_scripts" && fStat.isDirectory())) {
        continue;
      }

      fInfo.path = fInfo.path.replace(origDir, "."); //

      if (fStat.isDirectory()) {
        allFiles = allFiles.concat(filesListing(origDir, origPath));
        fInfo.type = "D";
        fInfo.mtime = fStat.mtime;
        allFiles.push(fInfo);
      } else {
        fInfo.type = "F";
        fInfo.mtime = fStat.mtime;
        fInfo.size = fStat.size;
        fInfo.checksum = computeChecksum(origDir + fInfo.path);
        allFiles.push(fInfo);
      }
    }
  } catch(err) {
    console.error(err);
  }

  return JSON.parse(JSON.stringify(allFiles));
}

module.exports = {
  filesListing
};
