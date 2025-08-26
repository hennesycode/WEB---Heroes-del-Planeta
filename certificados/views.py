from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.core.paginator import Paginator
from django.db.models import Q
from .models import Certificado

@login_required
def mis_certificados(request):
    # Base query optimizada
    qs = Certificado.objects.select_related('usuario').order_by('-creado')

    # ¿Puede ver todo?
    ver_todos = request.user.is_superuser or request.user.is_staff
    if not ver_todos:
        qs = qs.filter(usuario=request.user)

    # Búsqueda por nombre de certificado, username o email
    q = request.GET.get('q', '').strip()
    if q:
        qs = qs.filter(
            Q(nombre__icontains=q) |
            Q(usuario__username__icontains=q) |
            Q(usuario__email__icontains=q)
        )

    # Paginación
    paginator = Paginator(qs, 25)  # 25 por página
    page_number = request.GET.get('page')
    certificados = paginator.get_page(page_number)

    return render(
        request,
        'certificados/mis_certificados.html',
        {
            'certificados': certificados,  # Page object
            'ver_todos': ver_todos,
            'q': q,
        }
    )
