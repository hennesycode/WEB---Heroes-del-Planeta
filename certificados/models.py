from django.db import models
from django.conf import settings

class Certificado(models.Model):
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='certificados'
    )
    nombre = models.CharField(max_length=255)
    archivo = models.FileField(upload_to='certificados/')
    creado = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.nombre} - {self.usuario.username}"

