NEW_ENTRY = {
    "work": "Wrote a Dockerfile",
    "struggle": "Understanding image layers",
    "intention": "Push the image to ACR",
}


def create_entry(client):
    response = client.post("/entries", json=NEW_ENTRY)
    assert response.status_code == 200
    return response.json()["entry"]["id"]


def test_root_redirects_to_docs(client):
    response = client.get("/", follow_redirects=False)
    assert response.status_code in (302, 307)
    assert response.headers["location"] == "/docs"


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_create_and_get_entry(client):
    entry_id = create_entry(client)
    response = client.get(f"/entries/{entry_id}")
    assert response.status_code == 200
    assert response.json()["work"] == NEW_ENTRY["work"]


def test_create_rejects_too_long_text(client):
    response = client.post("/entries", json={**NEW_ENTRY, "work": "x" * 257})
    assert response.status_code == 422


def test_list_entries(client):
    create_entry(client)
    create_entry(client)
    response = client.get("/entries")
    assert response.status_code == 200
    assert response.json()["count"] == 2


def test_get_unknown_entry_returns_404(client):
    assert client.get("/entries/does-not-exist").status_code == 404


def test_patch_keeps_fields_that_were_not_sent(client):
    entry_id = create_entry(client)
    response = client.patch(f"/entries/{entry_id}", json={"work": "Pushed the image"})
    assert response.status_code == 200
    entry = client.get(f"/entries/{entry_id}").json()
    assert entry["work"] == "Pushed the image"
    assert entry["struggle"] == NEW_ENTRY["struggle"]
    assert entry["intention"] == NEW_ENTRY["intention"]


def test_patch_without_fields_returns_400(client):
    entry_id = create_entry(client)
    assert client.patch(f"/entries/{entry_id}", json={}).status_code == 400


def test_patch_unknown_entry_returns_404(client):
    response = client.patch("/entries/does-not-exist", json={"work": "x"})
    assert response.status_code == 404


def test_delete_entry(client):
    entry_id = create_entry(client)
    assert client.delete(f"/entries/{entry_id}").status_code == 200
    assert client.get(f"/entries/{entry_id}").status_code == 404


def test_delete_unknown_entry_returns_404(client):
    assert client.delete("/entries/does-not-exist").status_code == 404