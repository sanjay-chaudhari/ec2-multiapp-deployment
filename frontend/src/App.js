import React, { useState, useEffect } from "react";

const API = "/api/items";

export default function App() {
  const [items, setItems] = useState([]);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [error, setError] = useState("");

  const fetchItems = () =>
    fetch(API).then((r) => r.json()).then(setItems).catch(() => setError("Failed to load items"));

  useEffect(() => { fetchItems(); }, []);

  const handleAdd = async (e) => {
    e.preventDefault();
    if (!name.trim()) return;
    await fetch(API, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, description }),
    });
    setName("");
    setDescription("");
    fetchItems();
  };

  const handleDelete = async (id) => {
    await fetch(`${API}/${id}`, { method: "DELETE" });
    fetchItems();
  };

  return (
    <div style={{ maxWidth: 600, margin: "40px auto", fontFamily: "sans-serif", padding: "0 16px" }}>
      <h1>Items Manager</h1>
      {error && <p style={{ color: "red" }}>{error}</p>}

      <form onSubmit={handleAdd} style={{ display: "flex", gap: 8, marginBottom: 24, flexWrap: "wrap" }}>
        <input
          placeholder="Name *"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
          style={{ flex: 1, padding: 8, minWidth: 120 }}
        />
        <input
          placeholder="Description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          style={{ flex: 2, padding: 8, minWidth: 160 }}
        />
        <button type="submit" style={{ padding: "8px 16px" }}>Add</button>
      </form>

      {items.length === 0 ? (
        <p style={{ color: "#888" }}>No items yet. Add one above.</p>
      ) : (
        <ul style={{ listStyle: "none", padding: 0 }}>
          {items.map((item) => (
            <li key={item.id} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px 0", borderBottom: "1px solid #eee" }}>
              <div>
                <strong>{item.name}</strong>
                {item.description && <p style={{ margin: "4px 0 0", color: "#555", fontSize: 14 }}>{item.description}</p>}
                <small style={{ color: "#aaa" }}>{new Date(item.created_at).toLocaleString()}</small>
              </div>
              <button onClick={() => handleDelete(item.id)} style={{ background: "#e53e3e", color: "#fff", border: "none", padding: "6px 12px", cursor: "pointer", borderRadius: 4 }}>
                Delete
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
