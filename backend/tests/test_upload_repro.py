import os

import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.core.files.uploadedfile import SimpleUploadedFile


def test_video_upload_no_thumbnail():
    from django.http import QueryDict
    from django.utils.datastructures import MultiValueDict

    from apps.catalog.serializers import MediaUploadSerializer
    
    file_data = SimpleUploadedFile("video.mp4", b"data", content_type="video/mp4")
    
    data = MultiValueDict({
        'kind': ['video'],
        'duration_seconds': ['10'],
    })
    files = MultiValueDict({
        'files': [file_data]
    })
    
    q = QueryDict('', mutable=True)
    q.update(data)
    q.update(files)
    
    serializer = MediaUploadSerializer(data=q)
    print("Serializer is valid:", serializer.is_valid())
    print("Errors:", serializer.errors)

test_video_upload_no_thumbnail()
