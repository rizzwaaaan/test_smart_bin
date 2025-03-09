import React, { useEffect, useState } from "react";
import "./SmartDustbinPage.css";
import { Trash, Plus, X, MapPin, ArrowLeft } from "lucide-react";
import axios from "axios";
import { MapContainer, TileLayer, Marker, Popup, useMapEvents } from "react-leaflet";
import "leaflet/dist/leaflet.css";
import L from "leaflet";

// Custom map icon
const customIcon = new L.Icon({
  iconUrl: "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
});

const SmartDustbinPage = () => {
  const [notifications, setNotifications] = useState([]);
  const [newDustbin, setNewDustbin] = useState({
    location: "",
    bValue: "",
    nbValue: "",
    latitude: null,
    longitude: null,
  });
  const [selectedLocation, setSelectedLocation] = useState(null);
  const [mapCenter, setMapCenter] = useState([8.5241, 76.9366]); // Default: Trivandrum

  const API_BASE_URL = "http://127.0.0.1:5050"; // Update if needed

  // Fetch dustbin data
  const fetchDustbinData = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/api/dustbins`);
      setNotifications(response.data);
      console.log("Fetched Dustbin Data:", response.data);
    } catch (error) {
      console.error("Error fetching dustbin data:", error);
    }
  };

  useEffect(() => {
    fetchDustbinData();
    const interval = setInterval(fetchDustbinData, 5000);
    return () => clearInterval(interval);
  }, []);

  // Convert location name to coordinates (with proper headers)
  const getCoordinates = async (location) => {
    try {
      const response = await axios.get("https://nominatim.openstreetmap.org/search", {
        params: {
          q: location + ", Trivandrum, India",
          format: "json",
          limit: 1,
        },
        headers: {
          "User-Agent": "SmartWasteApp/1.0 (your-email@example.com)", // Change as needed
          "Accept-Language": "en",
        },
      });

      console.log("Geocoding API Response:", response.data);

      if (response.data.length > 0) {
        return { lat: parseFloat(response.data[0].lat), lon: parseFloat(response.data[0].lon) };
      } else {
        alert(`Location "${location}" not found. Try a different name.`);
        return null;
      }
    } catch (error) {
      console.error("Error fetching location coordinates:", error);
      alert("Failed to fetch location coordinates.");
      return null;
    }
  };

  // Handler for "Find Location" button
  const handleFindLocation = async () => {
    if (!newDustbin.location.trim()) {
      alert("Please enter a location.");
      return;
    }
    const coords = await getCoordinates(newDustbin.location);
    if (coords) {
      setMapCenter([coords.lat, coords.lon]);
      // Set initial marker position to the geocoded coordinates
      setNewDustbin((prev) => ({ ...prev, latitude: coords.lat, longitude: coords.lon }));
      console.log("New dustbin coordinates set to:", coords.lat, coords.lon);
    }
  };

  // Component to allow user to pin the exact location by clicking on the map
  const LocationMarker = () => {
    useMapEvents({
      click(e) {
        setNewDustbin((prev) => ({
          ...prev,
          latitude: e.latlng.lat,
          longitude: e.latlng.lng,
        }));
        console.log("Pinned coordinates:", e.latlng.lat, e.latlng.lng);
      },
    });
    return newDustbin.latitude && newDustbin.longitude ? (
      <Marker position={[newDustbin.latitude, newDustbin.longitude]} icon={customIcon}>
        <Popup>Selected Location</Popup>
      </Marker>
    ) : null;
  };

  // Handle adding a dustbin with the pinned coordinates
  const handleAddDustbin = async () => {
    if (!newDustbin.location.trim() || newDustbin.latitude === null || newDustbin.longitude === null) {
      alert("Please enter a location and pin the exact position on the map.");
      return;
    }
    try {
      await axios.post(`${API_BASE_URL}/api/add-dustbin`, newDustbin);
      alert("Dustbin added successfully!");
      setNewDustbin({ location: "", bValue: "", nbValue: "", latitude: null, longitude: null });
      fetchDustbinData();
    } catch (error) {
      console.error("Error adding dustbin:", error);
      alert("Failed to add dustbin.");
    }
  };

  // Show Map for a dustbin from the list
  const handleShowMap = (dustbin) => {
    if (dustbin.latitude && dustbin.longitude) {
      setSelectedLocation(dustbin);
      setMapCenter([parseFloat(dustbin.latitude), parseFloat(dustbin.longitude)]);
      console.log("Showing map for dustbin:", dustbin);
    } else {
      alert("Location data is missing.");
    }
  };

  // Delete dustbin
  const handleDeleteDustbin = async (location) => {
    try {
      const response = await axios.delete(`${API_BASE_URL}/api/delete-dustbin`, { data: { location } });
      alert(response.data.message);
      fetchDustbinData();
    } catch (error) {
      console.error("Error deleting dustbin:", error);
      alert("Failed to delete dustbin.");
    }
  };

  return (
    <div className="smart-dustbin-page">
      <h1>Smart Dustbin Notifications</h1>

      {/* Show Map if a dustbin from the list is selected */}
      {selectedLocation ? (
        <div className="map-container">
          <button className="back-button" onClick={() => setSelectedLocation(null)}>
            <ArrowLeft size={20} /> Back to List
          </button>
          <MapContainer center={mapCenter} zoom={15} style={{ height: "400px", width: "100%" }}>
            <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
            <Marker position={mapCenter} icon={customIcon}>
              <Popup>{selectedLocation.location}</Popup>
            </Marker>
          </MapContainer>
        </div>
      ) : (
        <>
          {/* Add New Dustbin Form with Map for Pinning Location */}
          <div className="add-dustbin-section">
            <h2>Add New Dustbin</h2>
            <input
              type="text"
              placeholder="Enter Location Name (e.g., MG Road)"
              value={newDustbin.location}
              onChange={(e) => setNewDustbin({ ...newDustbin, location: e.target.value })}
            />
            <button onClick={handleFindLocation} className="find-location-button">
              Find Location
            </button>
            <br />
            <input
              type="number"
              placeholder="B Value"
              value={newDustbin.bValue}
              onChange={(e) => setNewDustbin({ ...newDustbin, bValue: e.target.value })}
            />
            <input
              type="number"
              placeholder="NB Value"
              value={newDustbin.nbValue}
              onChange={(e) => setNewDustbin({ ...newDustbin, nbValue: e.target.value })}
            />
            <MapContainer center={mapCenter} zoom={15} style={{ height: "300px", width: "100%" }}>
              <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
              <LocationMarker />
            </MapContainer>
            <button onClick={handleAddDustbin} className="add-dustbin-button">
              <Plus size={20} /> Add Dustbin
            </button>
          </div>

          {/* Dustbin List */}
          <div className="notification-grid">
            {notifications.map((notification) => (
              <div key={notification._id} className="notification-bar">
                <div className="notification-content">
                  <h3>{notification.location}</h3>
                  <div className="notification-values">
                    <div className="value-item">
                      <span className="value-label">B:</span> {notification.bValue}
                    </div>
                    <div className="value-item">
                      <span className="value-label">NB:</span> {notification.nbValue}
                    </div>
                  </div>
                  <div className="notification-buttons">
                    <button className="map-button" onClick={() => handleShowMap(notification)}>
                      <MapPin size={20} /> Show on Map
                    </button>
                    <button className="delete-button" onClick={() => handleDeleteDustbin(notification.location)}>
                      <X size={20} /> Delete
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
};

export default SmartDustbinPage;