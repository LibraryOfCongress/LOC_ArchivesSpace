# Managed Authorities Endpoint

This plugin provides a new endpoint `/managed_authorities` which allows a user with
`update_subject_record` permissions to post a request with a resource uri and an
array of subject records. The subjects will be created if needed and linked to the
resource. All pre-existing resource-subject relationships will be deleted for the
resource.

## Example using ArchivesSnake

```python
from asnake.client import ASnakeClient
import json

client = ASnakeClient(baseurl="http://localhost:4567",
					  username="admin",
					  password="admin")
client.authorize()

response = client.post

subject_1 = {"vocabulary": "/vocabularies/1", "source": "lcgft",
			 "terms": [{"term": "Musicals", "vocabulary": "/vocabularies/1", "term_type": "genre_form"}],
			 "jsonmodel_type": "subject"}

subject_2 = {"vocabulary": "/vocabularies/1", "source": "lcgft",
			 "terms": [{"term": "Operas", "vocabulary": "/vocabularies/1", "term_type": "genre_form"}],
			 "jsonmodel_type": "subject"}


request = {
	"jsonmodel_type": "managed_authorities_request",
	"resource": {"ref": "/repositories/2/resources/24"},
	"subjects": [subject_1, subject_2]
}

res = client.post("/managed_authorities", json=request)
print(res)

```
