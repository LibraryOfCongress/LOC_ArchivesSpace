from asnake.client import ASnakeClient
import json

client = ASnakeClient(baseurl="http://localhost:4567",
                      username="admin",
                      password="admin")
client.authorize()

response = client.post
repos = client.get("repositories").json()

for r in repos:
    print(r.get("uri"))
# do what thou wilt with some repos

subject_1 = {"vocabulary": "/vocabularies/1", "source": "lcgft",
             "terms": [{"term": "Musicals", "vocabulary": "/vocabularies/1", "term_type": "genre_form"}],
             "jsonmodel_type": "subject"}

subject_2 = {"vocabulary": "/vocabularies/1", "source": "lcgft",
             "terms": [{"term": "Operas", "vocabulary": "/vocabularies/1", "term_type": "genre_form"}],
             "jsonmodel_type": "subject"}


request = {
    "jsonmodel_type": "managed_authorities_request",
    "resource": {"ref": "/repositories/2/resources/24"},
    "subjects": [subject_1]
}

res = client.post("/managed_authorities", json=request)
print(res)

