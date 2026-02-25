from django.contrib import admin
from .models import Scheme, SchemeChunk, EligibilityRule, FundConvergencePlan


@admin.register(Scheme)
class SchemeAdmin(admin.ModelAdmin):
    list_display = ['short_name', 'name', 'ministry', 'category', 'max_subsidy_pct', 'is_active']
    list_filter = ['category', 'is_active', 'ministry']
    search_fields = ['name', 'short_name']


@admin.register(SchemeChunk)
class SchemeChunkAdmin(admin.ModelAdmin):
    list_display = ['scheme', 'chunk_index', 'section_header', 'chunk_type', 'token_count']
    list_filter = ['chunk_type', 'scheme']
    search_fields = ['content', 'section_header']


@admin.register(EligibilityRule)
class EligibilityRuleAdmin(admin.ModelAdmin):
    list_display = ['scheme', 'rule_type', 'rule_text']
    list_filter = ['rule_type', 'scheme']


@admin.register(FundConvergencePlan)
class FundConvergencePlanAdmin(admin.ModelAdmin):
    list_display = ['project', 'total_cost_inr', 'panchayat_contribution_inr', 'savings_pct']
