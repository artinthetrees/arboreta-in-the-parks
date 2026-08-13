import React, { useEffect, useState, useRef } from "react"
import reactLogo from './assets/react.svg';
import viteLogo from './assets/vite.svg';
import heroImg from './assets/hero.png';
import sandyStream from './assets/sandystream.png'
import './App.css';

import { MapContainer, TileLayer, LayersControl, Marker, Popup, useMap, useMapEvents, GeoJSON, FeatureGroup, Polygon } from "react-leaflet"
import 'leaflet/dist/leaflet.css';

export function GeoJsonSummaryTable({ features, speciesKey, conditionKey }) {
  if (!features || features.length === 0) return <p>No data available</p>;

  // 1. Count items by looking inside the properties object
  const counts = features.reduce((acc, feature) => {
    const properties = feature.properties || {};
    const species = properties[speciesKey];
    const condition = properties[conditionKey];

    if (species && condition) {
      acc[species] = acc[species] || {};
      acc[species][condition] = (acc[species][condition] || 0) + 1;
    }
    return acc;
  }, {});

  // 2. Extract unique conditions dynamically for columns
  const conditionsList = Array.from(
    new Set(
      features
        .map((feature) => feature.properties?.[conditionKey])
        .filter(Boolean)
    )
  );

  // 3. Pre-calculate row totals and sort species descending
  const speciesList = Object.keys(counts).sort((a, b) => {
    const totalA = conditionsList.reduce((sum, cond) => sum + (counts[a][cond] || 0), 0);
    const totalB = conditionsList.reduce((sum, cond) => sum + (counts[b][cond] || 0), 0);
    return totalB - totalA; // High to low
  });

  const grandTotal = features.length;

  const columnTotals = conditionsList.reduce((acc, cond) => {
    acc[cond] = features.filter(
      (feature) => feature.properties?.[conditionKey] === cond
    ).length;
    return acc;
  }, {});

  return (
    <table>
      <thead>
        <tr>
          <th style={{ textTransform: 'capitalize' }}>{speciesKey}</th>
          {conditionsList.map((cond) => (
            <th key={cond}>{cond}</th>
          ))}
          <th>Total</th>
        </tr>
      </thead>
      <tbody>
        {speciesList.map((species) => {
          const rowTotal = conditionsList.reduce((sum, cond) => {
            return sum + (counts[species][cond] || 0);
          }, 0);

          return (
            <tr key={species}>
              <td>{species}</td>
              {conditionsList.map((cond) => (
                <td key={cond}>{counts[species][cond] || 0}</td>
              ))}
              <td><strong>{rowTotal}</strong></td>
            </tr>
          );
        })}
        <tr>
          <td><strong>Total</strong></td>
          {conditionsList.map((cond) => (
            <td key={cond}><strong>{columnTotals[cond]}</strong></td>
          ))}
          <td><strong>{grandTotal}</strong></td>
        </tr>
      </tbody>
    </table>
  );
}


// // Reusable component accepting GeoJSON features array and property keys
// export function GeoJsonSummaryTable({ features, speciesKey, conditionKey }) {
//   // Guard clause for empty or missing features
//   if (!features || features.length === 0) return <p>No data available</p>;

//   // Count items by looking inside the properties object
//   const counts = features.reduce((acc, feature) => {
//     const properties = feature.properties || {};
//     const species = properties[speciesKey];
//     const condition = properties[conditionKey];

//     if (species && condition) {
//       acc[species] = acc[species] || {};
//       acc[species][condition] = (acc[species][condition] || 0) + 1;
//     }
//     return acc;
//   }, {});

//   const speciesList = Object.keys(counts);

//   // Extract unique conditions dynamically from properties
//   const conditionsList = Array.from(
//     new Set(
//       features
//         .map((feature) => feature.properties?.[conditionKey])
//         .filter(Boolean)
//     )
//   );

//   const grandTotal = features.length;

//   // Calculate column totals dynamically from properties
//   const columnTotals = conditionsList.reduce((acc, cond) => {
//     acc[cond] = features.filter(
//       (feature) => feature.properties?.[conditionKey] === cond
//     ).length;
//     return acc;
//   }, {});

//   return (
//     <table>
//       <thead>
//         <tr>
//           {/* Capitalizes the first letter of your species key for the header */}
//           <th style={{ textTransform: 'capitalize' }}>{speciesKey}</th>
//           {conditionsList.map((cond) => (
//             <th key={cond}>{cond}</th>
//           ))}
//           <th>Total</th>
//         </tr>
//       </thead>
//       <tbody>
//         {speciesList.map((species) => {
//           const rowTotal = conditionsList.reduce((sum, cond) => {
//             return sum + (counts[species][cond] || 0);
//           }, 0);

//           return (
//             <tr key={species}>
//               <td>{species}</td>
//               {conditionsList.map((cond) => (
//                 <td key={cond}>{counts[species][cond] || 0}</td>
//               ))}
//               <td><strong>{rowTotal}</strong></td>
//             </tr>
//           );
//         })}
//         <tr>
//           <td><strong>Total</strong></td>
//           {conditionsList.map((cond) => (
//             <td key={cond}><strong>{columnTotals[cond]}</strong></td>
//           ))}
//           <td><strong>{grandTotal}</strong></td>
//         </tr>
//       </tbody>
//     </table>
//   );
// }


function ParkSelect({ setFilterVal, parkNames }) {
  // Set parkName using user selection from dropdown of list of all parkNames
  const parkNamesList = parkNames.map(dict => dict.name);

  const options = parkNamesList.map((parkName) => {
    return (
      <option value={parkName} key={parkName}>
        {parkName}
      </option>
    )
  })

  return (
    <>
      <label htmlFor="parkSelect" className="fs-3">
        Filter by park:{" "}
      </label>
      <select
        id="parkSelect"
        className="form-select form-select-lg mb-3"
        onChange={(e) => setFilterVal(e.target.value)}
      >
        {options}
      </select>
    </>
  )
}

// Internal component to handle map movement after data loads
function ZoomToGeoJSON({ geoJsonData }) {
  const map = useMap();
  const geoJsonRef = useRef(null);

  useEffect(() => {
    if (geoJsonData && geoJsonRef.current) {
      // Extract boundary coordinates from the processed GeoJSON layer
      const bounds = geoJsonRef.current.getBounds();

      // Auto-zoom with a pixel padding buffer around the shapes
      if (bounds.isValid()) {
        map.fitBounds(bounds, { padding: [50, 50] });
      }
    }
  }, [map, geoJsonData]);

  return (
    <GeoJSON
      ref={geoJsonRef}
      data={geoJsonData}
      style={{ color: 'purple', weight: 3 }}
    />
  );
}

// 1. Create a child component inside MapContainer
function ZoomTracker({ mapInitialZoom }) {
  const [zoomLevel, setZoomLevel] = useState(mapInitialZoom); // initial zoom

  const map = useMapEvents({
    zoomend: () => {
      setZoomLevel(map.getZoom()); // Get current zoom level
    },
  });

  return (
    <div style={{
      position: 'absolute',
      top: 10,
      left: 50,
      zIndex: 1000,
      background: 'white',
      padding: '5px'
    }}>
      Current Zoom: {zoomLevel}
    </div>
  );
}

function ValueCountsTable({ data }) {
  const entries = Object.entries(data).sort((a, b) => b[1] - a[1]);

  return (
    <table>
      <thead>
        <tr>
          <th>Item</th>
          <th>Count</th>
        </tr>
      </thead>
      <tbody>
        {entries.map(([key, value]) => (
          <tr key={key}>
            <td>{key}</td>
            <td>{value}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function App() {

  const [parkNames, setParkNames] = useState([])
  const parkNamesEndpoint = `http://localhost:8000/park-names`

  const [parkName, setParkName] = useState(null)
  const parkNameApiSafe = parkName ? parkName.replaceAll(" ", "+") : null
  const [treesInParkData, setTreesInParkData] = useState(null)
  const treesInParkEndpoint = parkName ? `http://localhost:8000/trees-in-park/?name=${parkNameApiSafe}` : null

  const mapInitialCenter = [41.88, -87.62]
  const mapInitialZoom = 10

  // set up a useEffect hook to run a fetch of park names list any time the site reloads
  useEffect(() => {
    fetch(parkNamesEndpoint)
      .then((res) => {
        console.log('Status:', res.status);
        return res.json()
      })
      .then((data) => {
        // console.log('Data:', data);
        setParkNames(data);
      })
      .catch(error => console.error('Error:', error)); // Log errors
  }, [])

  // set up a useEffect hook to run a fetch of trees in park data any time the trees in park endpoint (really the park name) const changes
  useEffect(() => {
    fetch(treesInParkEndpoint)
      .then((res) => {
        console.log('Status:', res.status);
        return res.json()
      })
      .then((data) => {
        // console.log('Data:', data);
        setTreesInParkData(data);
      })
      .catch(error => console.error('Error:', error)); // Log errors
  }, [treesInParkEndpoint])

  // parkName set by user selection from dropdown  
  console.log("park name: ", parkName)

  const parkGeomType = treesInParkData ? treesInParkData.features[0].geometry.type : undefined
  const parkGeom = treesInParkData ? treesInParkData.features[0].geometry.coordinates : undefined
  const numTreesInPark = treesInParkData ? treesInParkData.features[0].properties.contained_trees.features.length : undefined
  const treesInParkGeoJson = treesInParkData ? treesInParkData.features[0].properties.contained_trees : undefined
  const treesInParkList = treesInParkData ? treesInParkData.features[0].properties.contained_trees.features : undefined

  console.log("number of tree inventory points in park: ", numTreesInPark)

  const uniqueItems = (list, keyFn) => list.reduce((resultSet, item) =>
    resultSet.add(typeof keyFn === 'string' ? item[keyFn] : keyFn(item)),
    new Set);

  const uniqueItemsNonNull_n = (list, keyFn) => list.reduce((resultSet, item) =>
    (v => v !== null && v !== undefined && v !== "" && !v.startsWith("Unknown") ? resultSet.add(v) : resultSet)
      (typeof keyFn === 'string' ? item["properties"][keyFn] : keyFn(item)),
    new Set).size;

  const uniqueItemsNonNull = (list, keyFn) => list.reduce((resultSet, item) =>
    (v => v !== null && v !== undefined && v !== "" && !v.startsWith("Unknown") ? resultSet.add(v) : resultSet)
      (typeof keyFn === 'string' ? item["properties"][keyFn] : keyFn(item)),
    new Set);

  console.log("number of tree types in park: ", treesInParkData ? uniqueItemsNonNull_n(treesInParkList, 'common_name') : undefined);
  console.log("tree types in park: ", treesInParkData ? uniqueItemsNonNull(treesInParkList, 'common_name') : undefined);

  // 1. Get the frequency count of each key value (ignoring empty strings)
  const calcValueCounts = (list, key) => list.reduce((acc, obj) => {
    const value = obj["properties"][key];

    if (value !== "" && !value.startsWith("Unknown")) {
      acc[value] = (acc[value] || 0) + 1;
    }

    return acc;
  }, {});

  console.log("value counts: ", treesInParkData ? calcValueCounts(treesInParkList, "common_name") : undefined)
  const treeTypeValueCounts = treesInParkData ? calcValueCounts(treesInParkList, "common_name") : undefined
  const treeTypeUniqueCount = treesInParkData ? Object.keys(treeTypeValueCounts).length : undefined

  // // Get total number of permits across all community areas in the selected year
  // const totalPermits = currentYearData.reduce((accumulator, currentItem) => {
  //   return accumulator + currentItem.num_permits;
  // }, 0); // 0 is the initialValue
  // console.log('Total Permits:', totalPermits); 

  // // Get max number of permits in a single community area in the selected year
  // const maxPermits = Math.max(...currentYearData.map(item => item.num_permits));
  // console.log('Max Permits:', maxPermits); 

  // // Get quartiles of percent permits 
  // const getQuartiles = (arr, key) => {
  //   // 1. Extract key values from each dictionary in array of dictionaries and sort values numerically
  //   const values = arr.map(item => item[key]).sort((a, b) => a - b);

  //   const quantile = (sortedArr, q) => {
  //     const pos = (sortedArr.length - 1) * q;
  //     const base = Math.floor(pos);
  //     const rest = pos - base;
  //     if (sortedArr[base + 1] !== undefined) {
  //       return sortedArr[base] + rest * (sortedArr[base + 1] - sortedArr[base]);
  //     } else {
  //       return sortedArr[base];
  //     }
  //   };

  //   return {
  //     "q1": quantile(values, 0.25),
  //     "q2": quantile(values, 0.50), // Median
  //     "q3": quantile(values, 0.75)
  //   };
  // };

  // const permitPercentQuartiles = getQuartiles(currentYearData,'percent_permits')
  // console.log('Percent Permits Quartiles:', permitPercentQuartiles);

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

  // // define a fx that will run for each ca feature in the ca geojson to get the data 
  // // stored for that ca in the ca backend model/db and use that data to display 
  // // information specific to each ca on the frontend
  // function setAreaInteraction(feature, layer) {

  //   const ca_name = feature?.properties?.community || "Unknown";
  //   const ca_model_data = currentYearData.find(ca_entry => ca_entry.name === ca_name);

  //   const ca_model_data_str = JSON.stringify(ca_model_data, null, 2)
  //   const ca_num_permits_str = ca_model_data.num_permits.toString()

  //   let pop_up_str = `${ca_name}<br>Permits: ${ca_num_permits_str}`;
  //   let ca_color = getColor(ca_model_data.percent_permits)

  //   layer.setStyle({
  //     fillColor: ca_color, // Fill color based on quartile of permits issued
  //     fillOpacity: 0.5,    // Semi-transparent
  //     color: '#000000',    // Border color
  //     weight: 2            // Border weight
  //   })
  //   layer.on("mouseover", () => {
  //     layer.bindPopup(pop_up_str)
  //     layer.openPopup()
  //   })
  // }

  // define a fx that will run for each ca feature in the ca geojson to get the data 
  // stored for that ca in the ca backend model/db and use that data to display 
  // information specific to each ca on the frontend
  function setEachTree(feature, layer) {

    const model_data = feature?.properties || "Unknown";

    const model_data_str = JSON.stringify(model_data, null, 2)

    // let pop_up_str = `${ca_name}<br>Permits: ${ca_num_permits_str}`;
    // let ca_color = getColor(ca_model_data.percent_permits)

    // layer.setStyle({
    //   fillColor: ca_color, // Fill color based on quartile of permits issued
    //   fillOpacity: 0.5,    // Semi-transparent
    //   color: '#000000',    // Border color
    //   weight: 2            // Border weight
    // })
    layer.on("mouseover", () => {
      layer.bindPopup(model_data_str)
      layer.openPopup()
    })
  }

  return (
    <>
      <section id="center">
        {/* <div className="hero">
          <img src={sandyStream} className="base" width="170" height="170" alt="" />
        </div> */}
        <div>
          <h1>Arboreta in the Parks</h1>
        </div>
        <ParkSelect filterVal={parkName} setFilterVal={setParkName} parkNames={parkNames} />
        {/* <p className="fs-4">
          <b>Restaurant permits issued this year:</b> { totalPermits }
        </p> */}
        {treesInParkData && (
          <p className="fs-4">
            <b>Number of unique tree types identified in this park:</b> {treeTypeUniqueCount}
          </p>
        )}
        {/* {treesInParkData && treeTypeUniqueCount !== 0 && (
          <ValueCountsTable
            data={treeTypeValueCounts}
          />
        )} */}
        {treesInParkData && treeTypeUniqueCount !== 0 && (
          <GeoJsonSummaryTable
            features={treesInParkList}
            speciesKey="common_name"
            conditionKey="crown_condition"
          />
        )}
        <MapContainer
          id="city-map"
          center={mapInitialCenter}
          zoom={mapInitialZoom}
        >
          <LayersControl position="topright">

            {/* Default Base Map */}
            <LayersControl.BaseLayer name="OpenStreetMap">
              <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png"
              />
            </LayersControl.BaseLayer>

            {/* Base Layer: Esri Satellite */}
            <LayersControl.BaseLayer checked name="Satellite (Esri)">
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

            {/* <LayersControl.Overlay name="CA with counts">
              {currentYearData.length > 0 ? (
                <GeoJSON
                  data={COMMUNITY_AREAS}
                  onEachFeature={setAreaInteraction}
                  key={testyearlyDataEndpoint}
                />
              ) : null}
            </LayersControl.Overlay> */}

            {/* <ZoomToBounds data={parkGeom} /> */}

            <LayersControl.Overlay checked name="park boundary">
              {/* 
                The key prop forces React to completely recreate the layer 
                instead of updating it silently when geoJsonData switches from null to loaded
              */}
              {treesInParkData && (
                <ZoomToGeoJSON
                  key={JSON.stringify(treesInParkData)}
                  geoJsonData={treesInParkData}
                />
              )}
            </LayersControl.Overlay>

            <LayersControl.Overlay checked name="trees in park">
              {treesInParkGeoJson ? (
                <GeoJSON
                  key={JSON.stringify(treesInParkGeoJson)}
                  data={treesInParkGeoJson}
                  onEachFeature={setEachTree}
                // onEachFeature={setAreaInteraction}

                />
              ) : null}
            </LayersControl.Overlay>

            <ZoomTracker mapInitialZoom={mapInitialZoom} />

          </LayersControl>
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
