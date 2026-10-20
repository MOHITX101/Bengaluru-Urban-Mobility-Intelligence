import csv
import xml.etree.ElementTree as ET
from pathlib import Path


INPUT_FILE = Path(__file__).with_name("bmtc_bus_stops.kml")
OUTPUT_FILE = Path(__file__).with_name("bmtc_bus_stops.csv")

KML_NAMESPACE = {
    "kml": "http://www.opengis.net/kml/2.2"
}

OUTPUT_COLUMNS = [
    "object_id",
    "kgis_code",
    "department_code",
    "bus_stop_id",
    "bus_stop_name",
    "ward_id",
    "village_id",
    "status",
    "longitude",
    "latitude",
]


def clean(value):
    if value is None:
        return ""
    return value.strip()


tree = ET.parse(INPUT_FILE)
root = tree.getroot()

output_rows = []

for placemark in root.findall(".//kml:Placemark", KML_NAMESPACE):
    attributes = {}

    for element in placemark.findall(
        ".//kml:SimpleData",
        KML_NAMESPACE
    ):
        field_name = element.get("name")
        attributes[field_name] = clean(element.text)

    coordinates_text = placemark.findtext(
        ".//kml:Point/kml:coordinates",
        default="",
        namespaces=KML_NAMESPACE,
    )

    longitude = ""
    latitude = ""

    if coordinates_text:
        coordinate_parts = coordinates_text.strip().split()[0].split(",")

        if len(coordinate_parts) >= 2:
            longitude = clean(coordinate_parts[0])
            latitude = clean(coordinate_parts[1])

    output_rows.append(
        {
            "object_id": attributes.get("objectid", ""),
            "kgis_code": attributes.get("kgiscode", ""),
            "department_code": attributes.get("departmentcode", ""),
            "bus_stop_id": attributes.get("kgisbmtcbusstopid", ""),
            "bus_stop_name": attributes.get("kgisbmtcbusstopname", ""),
            "ward_id": attributes.get("kgiswardid", ""),
            "village_id": attributes.get("kgisvillageid", ""),
            "status": attributes.get("status", ""),
            "longitude": longitude,
            "latitude": latitude,
        }
    )


with OUTPUT_FILE.open(
    mode="w",
    encoding="utf-8",
    newline=""
) as output_handle:

    writer = csv.DictWriter(
        output_handle,
        fieldnames=OUTPUT_COLUMNS
    )

    writer.writeheader()
    writer.writerows(output_rows)


unique_stop_ids = {
    row["bus_stop_id"]
    for row in output_rows
    if row["bus_stop_id"]
}

unique_stop_names = {
    row["bus_stop_name"]
    for row in output_rows
    if row["bus_stop_name"]
}

missing_coordinates = sum(
    1
    for row in output_rows
    if not row["longitude"] or not row["latitude"]
)

print(f"Output file: {OUTPUT_FILE}")
print(f"Rows written: {len(output_rows)}")
print(f"Unique stop IDs: {len(unique_stop_ids)}")
print(f"Unique stop names: {len(unique_stop_names)}")
print(f"Missing coordinates: {missing_coordinates}")