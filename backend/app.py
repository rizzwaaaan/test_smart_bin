from flask import Flask, request, jsonify
from flask_cors import CORS
from pymongo import MongoClient
from flask_socketio import SocketIO
import json

app = Flask(__name__)
CORS(app)  # Enable CORS for HTTP APIs
socketio = SocketIO(app, cors_allowed_origins="*")  # Enable WebSockets

# Connect to MongoDB (adjust connection string as needed)
client = MongoClient(
    "mongodb+srv://admin:vq8o0yqH8iZEYj2j@cluster0.bmsri.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0",
    tls=True,
    tlsAllowInvalidCertificates=True
)
db = client["smart_waste_db"]
dustbins_collection = db["dustbin"]

# API Route to Add a Dustbin (with latitude and longitude)
@app.route("/api/add-dustbin", methods=["POST"])
def add_dustbin():
    try:
        data = request.json
        location = data.get("location")
        b_value = data.get("bValue")
        nb_value = data.get("nbValue")
        latitude = data.get("latitude")
        longitude = data.get("longitude")

        if not location or b_value is None or nb_value is None or latitude is None or longitude is None:
            return jsonify({"error": "Missing data"}), 400

        dustbin = {
            "location": location,
            "bValue": b_value,
            "nbValue": nb_value,
            "latitude": latitude,
            "longitude": longitude
        }
        
        result = dustbins_collection.insert_one(dustbin)
        dustbin["_id"] = str(result.inserted_id)

        # If the dustbin's fill levels exceed 85, emit a WebSocket alert
        if b_value > 85 or nb_value > 85:
            alert_data = {
                "message": f"Dustbin at {location} is nearly full!",
                "dustbin": dustbin
            }
            socketio.emit("dustbin_alert", alert_data)
            print("Alert emitted:", alert_data)

        return jsonify({"message": "Dustbin added successfully", "dustbin": dustbin}), 201

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# API Route to Update a Dustbin's Fill Level
@app.route("/api/update-dustbin", methods=["PUT"])
def update_dustbin():
    try:
        data = request.json
        location = data.get("location")
        b_value = data.get("bValue")
        nb_value = data.get("nbValue")

        if not location or b_value is None or nb_value is None:
            return jsonify({"error": "Missing data"}), 400

        result = dustbins_collection.update_one(
            {"location": location},
            {"$set": {"bValue": b_value, "nbValue": nb_value}}
        )

        if result.matched_count == 0:
            return jsonify({"error": "Dustbin not found"}), 404

        updated_dustbin = dustbins_collection.find_one({"location": location})
        updated_dustbin["_id"] = str(updated_dustbin["_id"])

        if b_value > 85 or nb_value > 85:
            alert_data = {
                "message": f"Dustbin at {location} is nearly full!",
                "dustbin": updated_dustbin
            }
            socketio.emit("dustbin_alert", alert_data)
            print("Alert emitted:", alert_data)

        return jsonify({"message": "Dustbin updated successfully", "dustbin": updated_dustbin}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# API Route to Get All Dustbins
@app.route("/api/dustbins", methods=["GET"])
def get_dustbins():
    try:
        dustbins = list(dustbins_collection.find({}, {
            "_id": 1,
            "location": 1,
            "bValue": 1,
            "nbValue": 1,
            "latitude": 1,
            "longitude": 1
        }))
        for dustbin in dustbins:
            dustbin["_id"] = str(dustbin["_id"])
        return jsonify(dustbins), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# API Route to Delete a Dustbin by Location
@app.route("/api/delete-dustbin", methods=["DELETE"])
def delete_dustbin():
    try:
        data = request.json
        location = data.get("location")
        if not location:
            return jsonify({"error": "Location required"}), 400

        result = dustbins_collection.delete_one({"location": location})
        if result.deleted_count == 0:
            return jsonify({"error": "Dustbin not found"}), 404

        return jsonify({"message": "Dustbin deleted successfully"}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Run the Flask Server using SocketIO
if __name__ == "__main__":
    socketio.run(app, debug=True, port=5050)
