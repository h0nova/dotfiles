#!/usr/bin/env bash
python3 - "$1" "$2" "$3" << 'PYEOF'
import sys

try:
    amount = float(sys.argv[1].replace(',', '.'))
    from_u = sys.argv[2].lower().strip()
    to_u   = sys.argv[3].lower().strip()
except:
    sys.exit(1)

LENGTH = {
    'm':1,'meter':1,'meters':1,'metre':1,
    'km':1000,'kilometer':1000,'kilometers':1000,'kilometre':1000,
    'cm':0.01,'centimeter':0.01,'centimetre':0.01,
    'mm':0.001,'millimeter':0.001,
    'mile':1609.344,'miles':1609.344,'mi':1609.344,
    'ft':0.3048,'foot':0.3048,'feet':0.3048,
    'in':0.0254,'inch':0.0254,'inches':0.0254,
    'yd':0.9144,'yard':0.9144,'yards':0.9144,
    'nm':1852,'nmi':1852,
}
MASS = {
    'kg':1,'kilogram':1,'kilograms':1,
    'g':0.001,'gram':0.001,'grams':0.001,
    'mg':0.000001,'milligram':0.000001,
    'lb':0.453592,'lbs':0.453592,'pound':0.453592,'pounds':0.453592,
    'oz':0.0283495,'ounce':0.0283495,'ounces':0.0283495,
    't':1000,'ton':1000,'tonne':1000,'tonnes':1000,
}
SPEED = {
    'm/s':1,'ms':1,
    'km/h':1/3.6,'kph':1/3.6,'kmh':1/3.6,
    'mph':0.44704,'mi/h':0.44704,
    'knot':0.514444,'knots':0.514444,'kt':0.514444,
}
VOLUME = {
    'l':1,'liter':1,'liters':1,'litre':1,'litres':1,
    'ml':0.001,'milliliter':0.001,'milliliters':0.001,
    'gal':3.78541,'gallon':3.78541,'gallons':3.78541,
    'qt':0.946353,'quart':0.946353,
    'pt':0.473176,'pint':0.473176,
    'cup':0.236588,'cups':0.236588,
    'floz':0.0295735,'fl.oz':0.0295735,
    'm3':1000,'cm3':0.001,
}
AREA = {
    'm2':1,'sqm':1,
    'km2':1e6,'sqkm':1e6,
    'cm2':0.0001,
    'ft2':0.092903,'sqft':0.092903,
    'mi2':2589988,'sqmi':2589988,
    'acre':4046.86,'acres':4046.86,
    'ha':10000,'hectare':10000,'hectares':10000,
}
DATA = {
    'bit':1,'bits':1,
    'byte':8,'bytes':8,
    'kb':8000,'kilobyte':8000,'kilobytes':8000,
    'mb':8e6,'megabyte':8e6,'megabytes':8e6,
    'gb':8e9,'gigabyte':8e9,'gigabytes':8e9,
    'tb':8e12,'terabyte':8e12,'terabytes':8e12,
    'kbit':1000,'mbit':1e6,'gbit':1e9,'tbit':1e12,
}

# Temperature (special case)
TEMP = {'c','°c','celsius','f','°f','fahrenheit','k','kelvin'}
TEMP_NAME = {
    'c':'°C','°c':'°C','celsius':'°C',
    'f':'°F','°f':'°F','fahrenheit':'°F',
    'k':'K','kelvin':'K',
}

if from_u in TEMP or to_u in TEMP:
    def to_celsius(v, u):
        if u in ('c','°c','celsius'):   return v
        if u in ('f','°f','fahrenheit'): return (v-32)*5/9
        if u in ('k','kelvin'):          return v-273.15
    def from_celsius(v, u):
        if u in ('c','°c','celsius'):   return v
        if u in ('f','°f','fahrenheit'): return v*9/5+32
        if u in ('k','kelvin'):          return v+273.15
    result = from_celsius(to_celsius(amount, from_u), to_u)
    name = TEMP_NAME.get(to_u, to_u.upper())
    print(f'{result:g} {name}')
    sys.exit(0)

result = None
for table in [LENGTH, MASS, SPEED, VOLUME, AREA, DATA]:
    fv = table.get(from_u)
    tv = table.get(to_u)
    if fv and tv:
        result = amount * fv / tv
        break

if result is None:
    print('Невідомі одиниці')
    sys.exit(1)

print(f'{result:g} {sys.argv[3]}')
PYEOF
