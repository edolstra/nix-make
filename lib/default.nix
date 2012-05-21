rec {

  pkgs = import <nixpkgs> {};

  stdenv = pkgs.stdenv;


  findFile = fn: searchPath:
    if searchPath == [] then []
    else
      let fn' = "${builtins.head searchPath}/${fn}"; in
      if builtins.pathExists fn' then [ { key = fn'; relative = fn; } ]
      else findFile fn (builtins.tail searchPath);
  

  compileC =
  { main
  , localIncludes ? "auto"
  , localIncludePath ? []
  , cFlags ? ""
  , sharedLib ? false
  , buildInputs ? []
  }:
  stdenv.mkDerivation {
    name = "compile-c";
    builder = ./compile-c.sh;

    localIncludes =
      if localIncludes == "auto" then
        map (x: [ x.key x.relative ]) (builtins.genericClosure {
          startSet = [ { key = main; relative = baseNameOf (toString main); } ];
          operator =
            { key, ... }:
            let
              includes = import (findIncludes { main = key; });
              includesFound = pkgs.lib.concatMap (fn: findFile fn localIncludePath) includes;
            in includesFound;
        })
      else
        localIncludes;
        
    inherit main buildInputs;
    
    cFlags = [
      "-O3" "-g" "-Wall"
      cFlags
      (if sharedLib then ["-fpic"] else [])
      #(map (p: "-I" + (relativise (dirOf main) p)) localIncludePath)
    ];
  };

  
  findIncludes = {main}: stdenv.mkDerivation {
    name = "find-includes";
    realBuilder = "${pkgs.perl}/bin/perl";
    args = [ ./find-includes.pl ];
    inherit main;
  };

    
  link =
    { objects, programName ? "program", libraries ? [], buildInputs ? [], flags ? [] }:
    stdenv.mkDerivation {
      name = "link";
      builder = ./link.sh;
      inherit objects programName libraries buildInputs flags;
    };

  
  makeLibrary = {objects, libraryName ? [], sharedLib ? false}:
  # assert sharedLib -> fold (obj: x: assert obj.sharedLib && x) false objects
  stdenv.mkDerivation {
    name = "library";
    builder = ./make-library.sh;
    inherit objects libraryName sharedLib;
  };

  
}
