from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import Usuario

class UsuarioAdmin(UserAdmin):
    model = Usuario
    list_display = ('username', 'email', 'es_aliado', 'nombre_conjunto', 'is_staff')
    fieldsets = UserAdmin.fieldsets + (
        ('Datos adicionales', {'fields': ('es_aliado', 'nombre_conjunto')}),
    )
    


admin.site.register(Usuario, UsuarioAdmin)
