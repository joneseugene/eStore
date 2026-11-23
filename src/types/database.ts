export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      allocation_lines: {
        Row: {
          basis_count: number
          created_at: string
          final_quantity: number
          id: string
          organization_id: string
          plan_id: string
          proposed_quantity: number
          to_unit_id: string
          updated_at: string
        }
        Insert: {
          basis_count?: number
          created_at?: string
          final_quantity?: number
          id?: string
          organization_id: string
          plan_id: string
          proposed_quantity?: number
          to_unit_id: string
          updated_at?: string
        }
        Update: {
          basis_count?: number
          created_at?: string
          final_quantity?: number
          id?: string
          organization_id?: string
          plan_id?: string
          proposed_quantity?: number
          to_unit_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "allocation_lines_plan_id_organization_id_fkey"
            columns: ["plan_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "allocation_plans"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "allocation_lines_to_unit_id_organization_id_fkey"
            columns: ["to_unit_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      allocation_plans: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          attribute_filters: Json
          basis: Database["public"]["Enums"]["allocation_basis"]
          basis_dimension_filter: Json
          basis_metric_id: string | null
          created_at: string
          created_by: string | null
          document_number: string | null
          from_unit_id: string
          id: string
          item_id: string
          notes: string | null
          organization_id: string
          pack_size_id: string | null
          period_id: string | null
          status: Database["public"]["Enums"]["allocation_status"]
          target_level_id: string
          total_quantity: number
          updated_at: string
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          attribute_filters?: Json
          basis: Database["public"]["Enums"]["allocation_basis"]
          basis_dimension_filter?: Json
          basis_metric_id?: string | null
          created_at?: string
          created_by?: string | null
          document_number?: string | null
          from_unit_id: string
          id?: string
          item_id: string
          notes?: string | null
          organization_id: string
          pack_size_id?: string | null
          period_id?: string | null
          status?: Database["public"]["Enums"]["allocation_status"]
          target_level_id: string
          total_quantity: number
          updated_at?: string
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          attribute_filters?: Json
          basis?: Database["public"]["Enums"]["allocation_basis"]
          basis_dimension_filter?: Json
          basis_metric_id?: string | null
          created_at?: string
          created_by?: string | null
          document_number?: string | null
          from_unit_id?: string
          id?: string
          item_id?: string
          notes?: string | null
          organization_id?: string
          pack_size_id?: string | null
          period_id?: string | null
          status?: Database["public"]["Enums"]["allocation_status"]
          target_level_id?: string
          total_quantity?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "allocation_plans_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "allocation_plans_basis_metric_id_organization_id_fkey"
            columns: ["basis_metric_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "metric_definitions"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "allocation_plans_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "allocation_plans_from_unit_id_organization_id_fkey"
            columns: ["from_unit_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "allocation_plans_item_id_organization_id_fkey"
            columns: ["item_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "allocation_plans_pack_size_id_organization_id_fkey"
            columns: ["pack_size_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "item_pack_sizes"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "allocation_plans_period_id_organization_id_fkey"
            columns: ["period_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "periods"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "allocation_plans_target_level_id_organization_id_fkey"
            columns: ["target_level_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "unit_levels"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      attribute_definitions: {
        Row: {
          created_at: string
          id: string
          key: string
          label: string
          options: Json | null
          organization_id: string
          required: boolean
          sort_order: number
          type: Database["public"]["Enums"]["attribute_type"]
          unit_level_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          key: string
          label: string
          options?: Json | null
          organization_id: string
          required?: boolean
          sort_order?: number
          type: Database["public"]["Enums"]["attribute_type"]
          unit_level_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          key?: string
          label?: string
          options?: Json | null
          organization_id?: string
          required?: boolean
          sort_order?: number
          type?: Database["public"]["Enums"]["attribute_type"]
          unit_level_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "attribute_definitions_unit_level_id_organization_id_fkey"
            columns: ["unit_level_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "unit_levels"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      audit_log: {
        Row: {
          action: string
          actor_id: string | null
          after: Json | null
          before: Json | null
          created_at: string
          entity: string
          entity_id: string | null
          id: number
          organization_id: string | null
        }
        Insert: {
          action: string
          actor_id?: string | null
          after?: Json | null
          before?: Json | null
          created_at?: string
          entity: string
          entity_id?: string | null
          id?: never
          organization_id?: string | null
        }
        Update: {
          action?: string
          actor_id?: string | null
          after?: Json | null
          before?: Json | null
          created_at?: string
          entity?: string
          entity_id?: string | null
          id?: never
          organization_id?: string | null
        }
        Relationships: []
      }
      dispatch_lines: {
        Row: {
          created_at: string
          discrepancy_reason: string | null
          dispatch_id: string
          id: string
          item_id: string
          lot_id: string | null
          organization_id: string
          quantity_received: number | null
          quantity_sent: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          discrepancy_reason?: string | null
          dispatch_id: string
          id?: string
          item_id: string
          lot_id?: string | null
          organization_id: string
          quantity_received?: number | null
          quantity_sent: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          discrepancy_reason?: string | null
          dispatch_id?: string
          id?: string
          item_id?: string
          lot_id?: string | null
          organization_id?: string
          quantity_received?: number | null
          quantity_sent?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "dispatch_lines_dispatch_id_organization_id_fkey"
            columns: ["dispatch_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "dispatches"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "dispatch_lines_item_id_organization_id_fkey"
            columns: ["item_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "dispatch_lines_lot_id_organization_id_fkey"
            columns: ["lot_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "stock_lots"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      dispatches: {
        Row: {
          allocation_plan_id: string | null
          approved_at: string | null
          approved_by: string | null
          created_at: string
          created_by: string | null
          dispatched_at: string | null
          dispatched_by: string | null
          document_number: string | null
          driver_name: string | null
          driver_phone: string | null
          from_unit_id: string
          id: string
          organization_id: string
          photo_paths: string[]
          received_at: string | null
          received_by: string | null
          received_by_name: string | null
          receiver_note: string | null
          status: Database["public"]["Enums"]["dispatch_status"]
          to_unit_id: string
          updated_at: string
          vehicle_number: string | null
        }
        Insert: {
          allocation_plan_id?: string | null
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string
          created_by?: string | null
          dispatched_at?: string | null
          dispatched_by?: string | null
          document_number?: string | null
          driver_name?: string | null
          driver_phone?: string | null
          from_unit_id: string
          id?: string
          organization_id: string
          photo_paths?: string[]
          received_at?: string | null
          received_by?: string | null
          received_by_name?: string | null
          receiver_note?: string | null
          status?: Database["public"]["Enums"]["dispatch_status"]
          to_unit_id: string
          updated_at?: string
          vehicle_number?: string | null
        }
        Update: {
          allocation_plan_id?: string | null
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string
          created_by?: string | null
          dispatched_at?: string | null
          dispatched_by?: string | null
          document_number?: string | null
          driver_name?: string | null
          driver_phone?: string | null
          from_unit_id?: string
          id?: string
          organization_id?: string
          photo_paths?: string[]
          received_at?: string | null
          received_by?: string | null
          received_by_name?: string | null
          receiver_note?: string | null
          status?: Database["public"]["Enums"]["dispatch_status"]
          to_unit_id?: string
          updated_at?: string
          vehicle_number?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "dispatches_allocation_plan_id_organization_id_fkey"
            columns: ["allocation_plan_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "allocation_plans"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "dispatches_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dispatches_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dispatches_dispatched_by_fkey"
            columns: ["dispatched_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dispatches_from_unit_id_organization_id_fkey"
            columns: ["from_unit_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "dispatches_received_by_fkey"
            columns: ["received_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dispatches_to_unit_id_organization_id_fkey"
            columns: ["to_unit_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      funding_sources: {
        Row: {
          created_at: string
          id: string
          is_active: boolean
          name: string
          organization_id: string
          type: Database["public"]["Enums"]["funding_source_type"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
          type: Database["public"]["Enums"]["funding_source_type"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
          type?: Database["public"]["Enums"]["funding_source_type"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "funding_sources_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      item_pack_sizes: {
        Row: {
          created_at: string
          id: string
          item_id: string
          name: string
          organization_id: string
          quantity_in_base: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          item_id: string
          name: string
          organization_id: string
          quantity_in_base: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          item_id?: string
          name?: string
          organization_id?: string
          quantity_in_base?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "item_pack_sizes_item_id_organization_id_fkey"
            columns: ["item_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      items: {
        Row: {
          attributes: Json
          base_unit: string
          category: string | null
          created_at: string
          id: string
          is_active: boolean
          is_perishable: boolean
          name: string
          organization_id: string
          sku: string
          updated_at: string
        }
        Insert: {
          attributes?: Json
          base_unit: string
          category?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          is_perishable?: boolean
          name: string
          organization_id: string
          sku: string
          updated_at?: string
        }
        Update: {
          attributes?: Json
          base_unit?: string
          category?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          is_perishable?: boolean
          name?: string
          organization_id?: string
          sku?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "items_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      memberships: {
        Row: {
          created_at: string
          id: string
          organization_id: string
          role_id: string
          unit_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          organization_id: string
          role_id: string
          unit_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          organization_id?: string
          role_id?: string
          unit_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "memberships_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "memberships_role_fkey"
            columns: ["role_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "memberships_unit_id_organization_id_fkey"
            columns: ["unit_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "memberships_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      metric_definitions: {
        Row: {
          created_at: string
          dimensions: Json
          id: string
          key: string
          label: string
          organization_id: string
          unit_level_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          dimensions?: Json
          id?: string
          key: string
          label: string
          organization_id: string
          unit_level_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          dimensions?: Json
          id?: string
          key?: string
          label?: string
          organization_id?: string
          unit_level_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "metric_definitions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "metric_definitions_unit_level_id_organization_id_fkey"
            columns: ["unit_level_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "unit_levels"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      metric_values: {
        Row: {
          created_at: string
          dimension_values: Json
          id: string
          metric_id: string
          organization_id: string
          period_id: string
          unit_id: string
          updated_at: string
          value: number
        }
        Insert: {
          created_at?: string
          dimension_values?: Json
          id?: string
          metric_id: string
          organization_id: string
          period_id: string
          unit_id: string
          updated_at?: string
          value: number
        }
        Update: {
          created_at?: string
          dimension_values?: Json
          id?: string
          metric_id?: string
          organization_id?: string
          period_id?: string
          unit_id?: string
          updated_at?: string
          value?: number
        }
        Relationships: [
          {
            foreignKeyName: "metric_values_metric_id_organization_id_fkey"
            columns: ["metric_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "metric_definitions"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "metric_values_period_id_organization_id_fkey"
            columns: ["period_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "periods"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "metric_values_unit_id_organization_id_fkey"
            columns: ["unit_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      organizations: {
        Row: {
          acronym: string
          created_at: string
          id: string
          name: string
          sector_template: string | null
          settings: Json
          slug: string
          updated_at: string
        }
        Insert: {
          acronym: string
          created_at?: string
          id?: string
          name: string
          sector_template?: string | null
          settings?: Json
          slug: string
          updated_at?: string
        }
        Update: {
          acronym?: string
          created_at?: string
          id?: string
          name?: string
          sector_template?: string | null
          settings?: Json
          slug?: string
          updated_at?: string
        }
        Relationships: []
      }
      periods: {
        Row: {
          created_at: string
          ends_on: string
          id: string
          is_current: boolean
          name: string
          organization_id: string
          starts_on: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          ends_on: string
          id?: string
          is_current?: boolean
          name: string
          organization_id: string
          starts_on: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          ends_on?: string
          id?: string
          is_current?: boolean
          name?: string
          organization_id?: string
          starts_on?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "periods_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      permissions: {
        Row: {
          category: string
          description: string
          key: string
          label: string
          scope: Database["public"]["Enums"]["permission_scope"]
          sort_order: number
        }
        Insert: {
          category: string
          description: string
          key: string
          label: string
          scope: Database["public"]["Enums"]["permission_scope"]
          sort_order: number
        }
        Update: {
          category?: string
          description?: string
          key?: string
          label?: string
          scope?: Database["public"]["Enums"]["permission_scope"]
          sort_order?: number
        }
        Relationships: []
      }
      profiles: {
        Row: {
          created_at: string
          full_name: string
          id: string
          is_platform_admin: boolean
          phone: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          full_name?: string
          id: string
          is_platform_admin?: boolean
          phone?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          full_name?: string
          id?: string
          is_platform_admin?: boolean
          phone?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      receipt_lines: {
        Row: {
          batch_number: string | null
          created_at: string
          expiry_date: string | null
          id: string
          item_id: string
          lot_id: string | null
          organization_id: string
          quantity_damaged: number
          quantity_on_waybill: number
          quantity_received: number
          receipt_id: string
          updated_at: string
        }
        Insert: {
          batch_number?: string | null
          created_at?: string
          expiry_date?: string | null
          id?: string
          item_id: string
          lot_id?: string | null
          organization_id: string
          quantity_damaged?: number
          quantity_on_waybill: number
          quantity_received: number
          receipt_id: string
          updated_at?: string
        }
        Update: {
          batch_number?: string | null
          created_at?: string
          expiry_date?: string | null
          id?: string
          item_id?: string
          lot_id?: string | null
          organization_id?: string
          quantity_damaged?: number
          quantity_on_waybill?: number
          quantity_received?: number
          receipt_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "receipt_lines_item_id_organization_id_fkey"
            columns: ["item_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "receipt_lines_lot_id_organization_id_fkey"
            columns: ["lot_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "stock_lots"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "receipt_lines_receipt_id_organization_id_fkey"
            columns: ["receipt_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "receipts"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      receipts: {
        Row: {
          created_at: string
          created_by: string | null
          document_number: string | null
          driver_name: string | null
          driver_phone: string | null
          funding_source_id: string
          id: string
          notes: string | null
          organization_id: string
          photo_paths: string[]
          posted_at: string | null
          posted_by: string | null
          received_at: string
          received_by: string | null
          status: Database["public"]["Enums"]["receipt_status"]
          supplier: string | null
          unit_id: string
          updated_at: string
          vehicle_number: string | null
          waybill_number: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          document_number?: string | null
          driver_name?: string | null
          driver_phone?: string | null
          funding_source_id: string
          id?: string
          notes?: string | null
          organization_id: string
          photo_paths?: string[]
          posted_at?: string | null
          posted_by?: string | null
          received_at?: string
          received_by?: string | null
          status?: Database["public"]["Enums"]["receipt_status"]
          supplier?: string | null
          unit_id: string
          updated_at?: string
          vehicle_number?: string | null
          waybill_number: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          document_number?: string | null
          driver_name?: string | null
          driver_phone?: string | null
          funding_source_id?: string
          id?: string
          notes?: string | null
          organization_id?: string
          photo_paths?: string[]
          posted_at?: string | null
          posted_by?: string | null
          received_at?: string
          received_by?: string | null
          status?: Database["public"]["Enums"]["receipt_status"]
          supplier?: string | null
          unit_id?: string
          updated_at?: string
          vehicle_number?: string | null
          waybill_number?: string
        }
        Relationships: [
          {
            foreignKeyName: "receipts_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "receipts_funding_source_id_organization_id_fkey"
            columns: ["funding_source_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "funding_sources"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "receipts_posted_by_fkey"
            columns: ["posted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "receipts_received_by_fkey"
            columns: ["received_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "receipts_unit_id_organization_id_fkey"
            columns: ["unit_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      role_permissions: {
        Row: {
          created_at: string
          organization_id: string
          permission_key: string
          role_id: string
        }
        Insert: {
          created_at?: string
          organization_id: string
          permission_key: string
          role_id: string
        }
        Update: {
          created_at?: string
          organization_id?: string
          permission_key?: string
          role_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "role_permissions_permission_key_fkey"
            columns: ["permission_key"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["key"]
          },
          {
            foreignKeyName: "role_permissions_role_id_organization_id_fkey"
            columns: ["role_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      roles: {
        Row: {
          created_at: string
          description: string
          id: string
          is_system: boolean
          key: string | null
          name: string
          organization_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string
          id?: string
          is_system?: boolean
          key?: string | null
          name: string
          organization_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string
          id?: string
          is_system?: boolean
          key?: string | null
          name?: string
          organization_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "roles_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_lots: {
        Row: {
          batch_number: string | null
          created_at: string
          expiry_date: string | null
          first_received_at: string
          funding_source_id: string
          id: string
          item_id: string
          organization_id: string
          updated_at: string
        }
        Insert: {
          batch_number?: string | null
          created_at?: string
          expiry_date?: string | null
          first_received_at?: string
          funding_source_id: string
          id?: string
          item_id: string
          organization_id: string
          updated_at?: string
        }
        Update: {
          batch_number?: string | null
          created_at?: string
          expiry_date?: string | null
          first_received_at?: string
          funding_source_id?: string
          id?: string
          item_id?: string
          organization_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_lots_funding_source_id_organization_id_fkey"
            columns: ["funding_source_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "funding_sources"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "stock_lots_item_id_organization_id_fkey"
            columns: ["item_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      stock_movements: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          idempotency_key: string | null
          item_id: string
          lot_id: string
          movement_type: Database["public"]["Enums"]["movement_type"]
          organization_id: string
          quantity: number
          reason: string | null
          source_id: string | null
          source_line_id: string | null
          source_type: string
          unit_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          idempotency_key?: string | null
          item_id: string
          lot_id: string
          movement_type: Database["public"]["Enums"]["movement_type"]
          organization_id: string
          quantity: number
          reason?: string | null
          source_id?: string | null
          source_line_id?: string | null
          source_type: string
          unit_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          idempotency_key?: string | null
          item_id?: string
          lot_id?: string
          movement_type?: Database["public"]["Enums"]["movement_type"]
          organization_id?: string
          quantity?: number
          reason?: string | null
          source_id?: string | null
          source_line_id?: string | null
          source_type?: string
          unit_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_movements_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_movements_item_id_organization_id_fkey"
            columns: ["item_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "stock_movements_lot_id_organization_id_fkey"
            columns: ["lot_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "stock_lots"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "stock_movements_unit_id_organization_id_fkey"
            columns: ["unit_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      unit_levels: {
        Row: {
          can_hold_stock: boolean
          created_at: string
          depth: number
          id: string
          is_end_point: boolean
          name: string
          organization_id: string
          plural_name: string
          updated_at: string
        }
        Insert: {
          can_hold_stock?: boolean
          created_at?: string
          depth: number
          id?: string
          is_end_point?: boolean
          name: string
          organization_id: string
          plural_name: string
          updated_at?: string
        }
        Update: {
          can_hold_stock?: boolean
          created_at?: string
          depth?: number
          id?: string
          is_end_point?: boolean
          name?: string
          organization_id?: string
          plural_name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "unit_levels_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      units: {
        Row: {
          attributes: Json
          code: string
          created_at: string
          id: string
          is_active: boolean
          latitude: number | null
          level_id: string
          longitude: number | null
          name: string
          organization_id: string
          parent_id: string | null
          path: unknown
          updated_at: string
        }
        Insert: {
          attributes?: Json
          code: string
          created_at?: string
          id?: string
          is_active?: boolean
          latitude?: number | null
          level_id: string
          longitude?: number | null
          name: string
          organization_id: string
          parent_id?: string | null
          path: unknown
          updated_at?: string
        }
        Update: {
          attributes?: Json
          code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          latitude?: number | null
          level_id?: string
          longitude?: number | null
          name?: string
          organization_id?: string
          parent_id?: string | null
          path?: unknown
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "units_level_id_organization_id_fkey"
            columns: ["level_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "unit_levels"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "units_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "units_parent_id_organization_id_fkey"
            columns: ["parent_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      user_permission_overrides: {
        Row: {
          created_at: string
          created_by: string | null
          effect: Database["public"]["Enums"]["permission_effect"]
          id: string
          organization_id: string
          permission_key: string
          reason: string | null
          unit_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          effect: Database["public"]["Enums"]["permission_effect"]
          id?: string
          organization_id: string
          permission_key: string
          reason?: string | null
          unit_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          effect?: Database["public"]["Enums"]["permission_effect"]
          id?: string
          organization_id?: string
          permission_key?: string
          reason?: string | null
          unit_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_permission_overrides_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_permission_overrides_permission_key_fkey"
            columns: ["permission_key"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["key"]
          },
          {
            foreignKeyName: "user_permission_overrides_unit_id_organization_id_fkey"
            columns: ["unit_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "user_permission_overrides_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      stock_balances: {
        Row: {
          item_id: string | null
          last_movement_at: string | null
          lot_id: string | null
          organization_id: string | null
          quantity: number | null
          unit_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "stock_movements_item_id_organization_id_fkey"
            columns: ["item_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "stock_movements_lot_id_organization_id_fkey"
            columns: ["lot_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "stock_lots"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "stock_movements_unit_id_organization_id_fkey"
            columns: ["unit_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "units"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
    }
    Functions: {
      my_permissions: { Args: { p_unit: string }; Returns: string[] }
    }
    Enums: {
      allocation_basis: "metric" | "end_point_count" | "manual"
      allocation_status: "draft" | "approved" | "executed" | "cancelled"
      attribute_type: "text" | "number" | "boolean" | "select" | "multi_select"
      dispatch_status:
        | "draft"
        | "approved"
        | "in_transit"
        | "delivered"
        | "disputed"
        | "cancelled"
      funding_source_type: "government" | "multilateral" | "ngo" | "other"
      movement_type:
        | "receipt"
        | "dispatch_out"
        | "dispatch_in"
        | "issue"
        | "adjustment"
        | "loss_damage"
        | "return"
      permission_effect: "grant" | "deny"
      permission_scope: "organization" | "unit"
      receipt_status: "draft" | "posted"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      allocation_basis: ["metric", "end_point_count", "manual"],
      allocation_status: ["draft", "approved", "executed", "cancelled"],
      attribute_type: ["text", "number", "boolean", "select", "multi_select"],
      dispatch_status: [
        "draft",
        "approved",
        "in_transit",
        "delivered",
        "disputed",
        "cancelled",
      ],
      funding_source_type: ["government", "multilateral", "ngo", "other"],
      movement_type: [
        "receipt",
        "dispatch_out",
        "dispatch_in",
        "issue",
        "adjustment",
        "loss_damage",
        "return",
      ],
      permission_effect: ["grant", "deny"],
      permission_scope: ["organization", "unit"],
      receipt_status: ["draft", "posted"],
    },
  },
} as const
