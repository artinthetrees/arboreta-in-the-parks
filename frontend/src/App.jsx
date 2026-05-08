import React, { useEffect, useState } from "react"
import reactLogo from './assets/react.svg';
import viteLogo from './assets/vite.svg';
import heroImg from './assets/hero.png';
import './App.css';

import { MapContainer, TileLayer, GeoJSON } from "react-leaflet"
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

  return (
    <>
      <section id="center">
        <div className="hero">
          <img src={heroImg} className="base" width="170" height="179" alt="" />
          <img src={reactLogo} className="framework" alt="React logo" />
          <img src={viteLogo} className="vite" alt="Vite logo" />
        </div>
        <div>
          <h1>Get started - woohoo!</h1>
          <p>
            Edit <code>src/App.jsx</code> and save to test <code>HMR</code>
          </p>
        </div>
        <YearSelect filterVal={year} setFilterVal={setYear} />
        <div>
          <h1>Year is {year}</h1>
        </div>
        <MapContainer
          id="restaurant-map"
          center={[41.88, -87.62]}
          zoom={10}
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png"
          />
          <GeoJSON 
            data={COMMUNITY_AREAS} 
            // onEachFeature={setAreaInteraction}
            // key={maxPermits}
          />
          {/* {currentYearData.length > 0 ? (
            <GeoJSON
              data={RAW_COMMUNITY_AREAS}
              onEachFeature={setAreaInteraction}
              key={maxPermits}
            />
          ) : null} */}
        </MapContainer>
      </section>

      <div className="ticks"></div>

      <section id="next-steps">
        <div id="docs">
          <svg className="icon" role="presentation" aria-hidden="true">
            <use href="/icons.svg#documentation-icon"></use>
          </svg>
          <h2>Documentation</h2>
          <p>Your questions, answered</p>
          <ul>
            <li>
              <a href="https://vite.dev/" target="_blank">
                <img className="logo" src={viteLogo} alt="" />
                Explore Vite
              </a>
            </li>
            <li>
              <a href="https://react.dev/" target="_blank">
                <img className="button-icon" src={reactLogo} alt="" />
                Learn more
              </a>
            </li>
          </ul>
        </div>
        <div id="social">
          <svg className="icon" role="presentation" aria-hidden="true">
            <use href="/icons.svg#social-icon"></use>
          </svg>
          <h2>Connect with us</h2>
          <p>Join the Vite community</p>
          <ul>
            <li>
              <a href="https://github.com/vitejs/vite" target="_blank">
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
              <a href="https://chat.vite.dev/" target="_blank">
                <svg
                  className="button-icon"
                  role="presentation"
                  aria-hidden="true"
                >
                  <use href="/icons.svg#discord-icon"></use>
                </svg>
                Discord
              </a>
            </li>
            <li>
              <a href="https://x.com/vite_js" target="_blank">
                <svg
                  className="button-icon"
                  role="presentation"
                  aria-hidden="true"
                >
                  <use href="/icons.svg#x-icon"></use>
                </svg>
                X.com
              </a>
            </li>
            <li>
              <a href="https://bsky.app/profile/vite.dev" target="_blank">
                <svg
                  className="button-icon"
                  role="presentation"
                  aria-hidden="true"
                >
                  <use href="/icons.svg#bluesky-icon"></use>
                </svg>
                Bluesky
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
