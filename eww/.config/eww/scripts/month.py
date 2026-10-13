#!/usr/bin/env python3
# Calendar for the dashboard, one JSON object:
#   {"month": "October 2026", "weeks": [[{"d": "", "c": "pad"}, {"d": "1", "c": ""}, ...], ...],
#    "greeting": "good morning", "winter": "69 days till winter"}
# Weeks start on Sunday. Winter = Dec 21 solstice to Mar 20 equinox.
import calendar, datetime, json

today = datetime.date.today()
cal = calendar.Calendar(firstweekday=6)

weeks = []
for week in cal.monthdatescalendar(today.year, today.month):
    row = []
    for day in week:
        if day.month != today.month:
            row.append({"d": str(day.day), "c": "pad"})
        else:
            row.append({"d": str(day.day), "c": "today" if day == today else "weekend" if day.weekday() >= 5 else ""})
    weeks.append(row)

hour = datetime.datetime.now().hour
greeting = ("good night" if hour < 5 else "good morning" if hour < 12
            else "good afternoon" if hour < 17 else "good evening" if hour < 22 else "good night")

# Winter Countdown:
start = datetime.date(today.year, 12, 21)
end = datetime.date(today.year, 3, 20)
if today >= start:
    winter = f"winter · {(datetime.date(today.year + 1, 3, 20) - today).days} days left"
elif today <= end:
    winter = f"winter · {(end - today).days} days left"
else:
    n = (start - today).days
    winter = f"{n} {'day' if n == 1 else 'days'} till winter"

print(json.dumps({"month": today.strftime("%B %Y").lower(), "weeks": weeks, "greeting": greeting, "winter": winter}))
