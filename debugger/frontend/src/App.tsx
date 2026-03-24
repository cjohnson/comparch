import { useState } from 'react'
import reactLogo from './assets/react.svg'
import viteLogo from './assets/vite.svg'
import heroImg from './assets/hero.png'
import './App.css'

function App() {
  let rows = [];
  for (var i = 0; i < 32; i++) {
    rows.push(
      <tr>
        <td>X{i}</td>
        <td>0</td>
      </tr>
    );
  }

  return (
    <>
      <table>
        <tr>
          <th>Register</th>
          <th>Value</th>
        </tr>
        {rows}
      </table>
    </>
  )
}

export default App
