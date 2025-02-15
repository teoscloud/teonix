{ inputs, ...}: {
  programs.hyprlux = {
    enable = true;

    #night_light = {
      #enabled = true;
      # Manual sunset and sunrise
      #start_time = "22:00";
      #end_time = "06:00";
      # Automatic sunset and sunrise
      #latitude = 46.056946;
      #longitude = 14.505751;
      #temperature = 3500;
    #};

    vibrance_configs = [
      {
        window_class = "steam_app_1172470";
        window_title = "Apex Legends";
        strength = 80;
      }
      {
        window_class = "gamescope";
        window_title = "Counter-Strike 2";
        strength = 80;
      }
      {
        window_class = "cs2";
        strength = 80;
      }
      #{
      #  window_title = "Counter-Strike 2";
      #  strength = 80;
      #}
    ];
  };
}