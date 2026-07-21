import React, { useEffect, useState } from "react"
import reactLogo from './assets/react.svg';
import viteLogo from './assets/vite.svg';
import heroImg from './assets/hero.png';
import sandyStream from './assets/sandystream.png'
import './App.css';

import { MapContainer, TileLayer, LayersControl, GeoJSON } from "react-leaflet"
import 'leaflet/dist/leaflet.css';

import RAW_COMMUNITY_AREAS from "../data/raw/community-areas.geojson?raw"
const COMMUNITY_AREAS = JSON.parse(RAW_COMMUNITY_AREAS);

function YearSelect({ setFilterVal }) {
  // Filter by the permit issue year for each restaurant
  const startYear = 2026
  const years = [...Array(11).keys()].map((increment) => {
    return startYear - increment
  })
  const options = years.map((year) => {
    return (
      <option value={year} key={year}>
        {year}
      </option>
    )
  })

  return (
    <>
      <label htmlFor="yearSelect" className="fs-3">
        Filter by year:{" "}
      </label>
      <select
        id="yearSelect"
        className="form-select form-select-lg mb-3"
        onChange={(e) => setFilterVal(e.target.value)}
      >
        {options}
      </select>
    </>
  )
}

function App() {
  const [count, setCount] = useState(0)
  const [response, setResponse] = useState("");
  
  const [year, setYear] = useState(2026)
  const [currentYearData, setCurrentYearData] = useState([])
  const yearlyDataEndpoint = `/map-data/?year=${year}`
  const testyearlyDataEndpoint = `http://localhost:8000/map-data/?year=${year}`

  // set up a useEffect hook to run a fetch of currentYearData any time the yearlyDataEndpoint const changes
  useEffect(() => {
    fetch(testyearlyDataEndpoint)
      .then((res) => {
        console.log('Status:', res.status);
        return res.json()
      })  
      .then((data) => {
        console.log('Data:', data);
        setCurrentYearData(data);
      })
      .catch(error => console.error('Error:', error)); // Log errors
  }, [testyearlyDataEndpoint])

  // set up a useEffect hook to print currentYearData to console any time currentYearData const changes - just for testing
  // useEffect(() => {
  //   console.log('Updated State:', currentYearData);
  // }, [currentYearData]);

  // Get total number of permits across all community areas in the selected year
  const totalPermits = currentYearData.reduce((accumulator, currentItem) => {
    return accumulator + currentItem.num_permits;
  }, 0); // 0 is the initialValue
  console.log('Total Permits:', totalPermits); 

  // Get max number of permits in a single community area in the selected year
  const maxPermits = Math.max(...currentYearData.map(item => item.num_permits));
  console.log('Max Permits:', maxPermits); 

  // Get quartiles of percent permits 
  const getQuartiles = (arr, key) => {
    // 1. Extract key values from each dictionary in array of dictionaries and sort values numerically
    const values = arr.map(item => item[key]).sort((a, b) => a - b);
    
    const quantile = (sortedArr, q) => {
      const pos = (sortedArr.length - 1) * q;
      const base = Math.floor(pos);
      const rest = pos - base;
      if (sortedArr[base + 1] !== undefined) {
        return sortedArr[base] + rest * (sortedArr[base + 1] - sortedArr[base]);
      } else {
        return sortedArr[base];
      }
    };

    return {
      "q1": quantile(values, 0.25),
      "q2": quantile(values, 0.50), // Median
      "q3": quantile(values, 0.75)
    };
  };

  const permitPercentQuartiles = getQuartiles(currentYearData,'percent_permits')
  console.log('Percent Permits Quartiles:', permitPercentQuartiles);

  // define a fx that determines which quartile of num/percent of permits a ca is in 
  // and assigns it a color based on its quartile
  function getColor(percentageOfPermits) {
    
    const communityAreaColors = ["#eff3ff", "#bdd7e7", "#6baed6", "#2171b5"]

    if (percentageOfPermits <= permitPercentQuartiles.q1) {
      return communityAreaColors[0];
    } else if (percentageOfPermits <= permitPercentQuartiles.q2) {
      return communityAreaColors[1];
    } else if (percentageOfPermits <= permitPercentQuartiles.q3) {
      return communityAreaColors[2];
    } else {
      return communityAreaColors[3];
    }

  }

  // define a fx that will run for each ca feature in the ca geojson to get the data 
  // stored for that ca in the ca backend model/db and use that data to display 
  // information specific to each ca on the frontend
  function setAreaInteraction(feature, layer) {
    
    const ca_name = feature?.properties?.community || "Unknown";
    const ca_model_data = currentYearData.find(ca_entry => ca_entry.name === ca_name);
    
    const ca_model_data_str = JSON.stringify(ca_model_data, null, 2)
    const ca_num_permits_str = ca_model_data.num_permits.toString()
    
    let pop_up_str = `${ca_name}<br>Permits: ${ca_num_permits_str}`;
    let ca_color = getColor(ca_model_data.percent_permits)
    
    layer.setStyle({
      fillColor: ca_color, // Fill color based on quartile of permits issued
      fillOpacity: 0.5,    // Semi-transparent
      color: '#000000',    // Border color
      weight: 2            // Border weight
    })
    layer.on("mouseover", () => {
      layer.bindPopup(pop_up_str)
      layer.openPopup()
    })
  }

  return (
    <>
      <section id="center">
        <div className="hero">
          <img src={sandyStream} className="base" width="170" height="170" alt="" />
        </div>
        <div>
          <h1>Let's explore!</h1>
        </div>
        <YearSelect filterVal={year} setFilterVal={setYear} />
        {/* <div>
          <h1>Year is {year}</h1>
        </div> */}
        <p className="fs-4">
          <b>Restaurant permits issued this year:</b> { totalPermits }
        </p>
        <p className="fs-4">
          <b>Maximum number of restaurant permits issued in a single community area:</b> { maxPermits }
        </p>
        <MapContainer
          id="restaurant-map"
          center={[41.88, -87.62]}
          zoom={10}
        >
          <LayersControl position="topright">
        
            {/* Default Base Map */}
            <LayersControl.BaseLayer checked name="OpenStreetMap">
              <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png"
              />
            </LayersControl.BaseLayer>

            {/* Base Layer: Esri Satellite */}
            <LayersControl.BaseLayer name="Satellite (Esri)">
              <TileLayer
                url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
                attribution='Tiles &copy; Esri &mdash; Source: Esri, i-cubed, USDA, USGS, AEX, GeoEye, Getmapping, Aerogrid, IGN, IGP, UPR-EGP, and the GIS User Community'
              />
            </LayersControl.BaseLayer>

            {/* Alternative Base Map */}
            <LayersControl.BaseLayer name="CartoDB Light">
              <TileLayer
                attribution='&copy; <a href="https://carto.com/attributions">CARTO</a>'
                url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
                subdomains='abcd'
              />
            </LayersControl.BaseLayer>

          </LayersControl>
          
          {currentYearData.length > 0 ? (
            <GeoJSON
              data={COMMUNITY_AREAS}
              onEachFeature={setAreaInteraction}
              key={testyearlyDataEndpoint}
            />
          ) : null}
        </MapContainer>
      </section>

      <div className="ticks"></div>

      <section id="next-steps">
        <div id="docs">
          <svg className="icon" role="presentation" aria-hidden="true">
            <use href="/icons.svg#documentation-icon"></use>
          </svg>
          <h2>Documentation</h2>
          <p>Find code for this project here:</p>
          <ul>
            <li>
              <a href="https://github.com/artinthetrees/test" target="_blank">
                <svg
                  className="button-icon"
                  role="presentation"
                  aria-hidden="true"
                >
                  <use href="/icons.svg#github-icon"></use>
                </svg>
                GitHub repo for this project
              </a>
            </li>
          </ul>
        </div>
        <div id="social">
          <svg className="icon" role="presentation" aria-hidden="true">
            <use href="/icons.svg#social-icon"></use>
          </svg>
          <h2>Connect with me</h2>
          <p>Find me here:</p>
          <ul>
            <li>
              <a href="https://github.com/artinthetrees" target="_blank">
                <svg
                  className="button-icon"
                  role="presentation"
                  aria-hidden="true"
                >
                  <use href="/icons.svg#github-icon"></use>
                </svg>
                GitHub
              </a>
            </li>
            <li>
              <a href="https://www.linkedin.com/in/andreatentner/" target="_blank">
                <svg
                  className="button-icon"
                  role="presentation"
                  aria-hidden="true"
                >
                  <use href="/icons.svg#linkedin-icon"></use>
                </svg>
                LinkedIn
              </a>
            </li>
          </ul>
        </div>
      </section>

      <div className="ticks"></div>
      <section id="spacer"></section>
    </>
  );
}

export default App;
