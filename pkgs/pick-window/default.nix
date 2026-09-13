{ writeShellApplication }:
writeShellApplication {
  name = "pick-window";
  text = builtins.readFile ./pick-window;
}
