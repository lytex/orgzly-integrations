from datetime import datetime, timedelta
import astral
import astral.sun

city = astral.LocationInfo("Madrid", "Spain", "Europe/Madrid", 40.0, -3.5)
s = astral.sun.sun(city.observer, date=datetime.today(), tzinfo=city.timezone)


def solar_hour(x):
    if not -1 <= x <= 1:
        raise ValueError("Solar hour cannot be less than -1 or greater than 1")
    s["sunrise"] + (s["sunset"] - s["sunrise"]) * (x + 1) / 2


scheduled = {
    "613d58e9-d4ab-4f60-a109-a8785e1d71a1": {
        "SCHEDULED": lambda: (datetime.today() + timedelta(days=0))
        .replace(hour=21, minute=0)
        .strftime("<%Y-%m-%d %a %H:%M ++1d>"),
        "DEADLINE": lambda: (datetime.today() + timedelta(days=0))
        .replace(hour=22, minute=0)
        .strftime("<%Y-%m-%d %a %H:%M ++1d>"),
    }
}
