from django.shortcuts import render
from django.http import HttpResponse

def pharmacy(request):
    return HttpResponse("<h1>Pharmacy Management System</h1>")