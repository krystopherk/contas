{ pkgs, ... }: {
  channel = "stable-23.11";
  packages = [
    pkgs.jdk17
    pkgs.flutter
  ];
  idx = {
    extensions = ["Dart-Code.flutter"];
    previews = {
      enable = true;
      previews = {
        android = {
          command = ["flutter" "run" "--machine" "-d" "android" "-d" "localhost:5555"];
          manager = "flutter";
        };
      };
    };
  };
}
