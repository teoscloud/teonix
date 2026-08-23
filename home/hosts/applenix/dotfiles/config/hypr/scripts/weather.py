import requests
import os

weather_icons = {
    '200': '🌩🧛🏻‍♂️',
    '201': '⛈🧛🏻‍♂️',
    '202': '⛈🧛🏻‍♂️',
    '210': '🌩🧛🏻‍♂️',
    '211': '🌩🧛🏻‍♂️',
    '212': '🌩🧛🏻‍♂️',
    '221': '🌩🧛🏻‍♂️',
    '230': '🌩🧛🏻‍♂️',
    '232': '⛈🧛🏻‍♂️',  
    '300': '🌧🧛🏻‍♂️',
    '301': '🌧🧛🏻‍♂️',
    '302': '🌧🧛🏻‍♂️',
    '310': '🌨🧛🏻‍♂️',
    '311': '🌨🧛🏻‍♂️',
    '312': '🌨🧛🏻‍♂️',
    '313': '🌨🧛🏻‍♂️',
    '314': '🌨🧛🏻‍♂️',
    '321': '🌧🧛🏻‍♂️', 
    '500': '🌧🧛🏻‍♂️',
    '501': '🌧🧛🏻‍♂️',
    '502': '🌧🧛🏻‍♂️',
    '503': '🌧🧛🏻‍♂️',
    '504': '🌧🧛🏻‍♂️',
    '511': '🌧🧛🏻‍♂️',
    '520': '🌧🧛🏻‍♂️',
    '521': '🌧🧛🏻‍♂️',
    '522': '🌧🧛🏻‍♂️',
    '531': '🌧🧛🏻‍♂️', 
    '600': '❄️🧛🏻‍♂️',
    '601': '❄️🧛🏻‍♂️',
    '602': '❄️🧛🏻‍♂️',
    '611': '❄️🧛🏻‍♂️',
    '612': '❄️🧛🏻‍♂️',
    '613': '❄️🧛🏻‍♂️',
    '615': '❄️🧛🏻‍♂️',
    '616': '❄️🧛🏻‍♂️',
    '620': '❄️🧛🏻‍♂️',
    '621': '❄️🧛🏻‍♂️',
    '622': '❄️🧛🏻‍♂️',  
    '701': '🌫',
    '711': '🌫',
    '721': '🌫',
    '731': '🌫',
    '741': '🌫',
    '751': '🌫',
    '761': '🌫',
    '762': '🌫',
    '771': '🌫',
    '781': '🌫', 
    '800': '🌞', 
    '801': '⛅️',
    '802': '⛅️',
    '803': '⛅️',
    '804': '☁️🧛🏻‍♂️',
}

def get_api_key(filepath="~/.config/hypr/scripts/secrets/weather_api_key.txt"):
    # Expand the '~' to your home directory
    expanded_path = os.path.expanduser(filepath)
    try:
        with open(expanded_path, "r") as f:
            return f.read().strip()
    except Exception as e:
        raise Exception(f"API key file not found at {expanded_path}") from e

API_KEY = get_api_key()
LAT = 59.3293
LON = 18.0686

URL = f"https://api.openweathermap.org/data/2.5/weather?lat={LAT}&lon={LON}&units=metric&appid={API_KEY}"

try:
    response = requests.get(URL)
    response.raise_for_status()  # Ensure status code 200
    data = response.json()

    # Ensure data contains necessary fields
    icon_id = str(data['weather'][0]['id']) if 'weather' in data else "800"
    current_icon = weather_icons.get(icon_id, "🌥")  # Default to cloudy icon
    weather_desc = data['weather'][0]['main'] if 'weather' in data else "Unknown"
    temp = int(data['main']['temp']) if 'main' in data else "N/A"

    output = f"{current_icon} {weather_desc} {temp}°C"
except:
    # If there's any error, fallback to snowflake icon
    output = "❄️"

print(output)




