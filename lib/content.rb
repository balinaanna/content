module Acts
  module Asset
    class Railtie < Rails::Railtie
      initializer 'acts_as_asset.extend_active_record' do
        ::ActiveRecord::Base.extend ActiveRecordMethods
      end

      config.after_initialize do
        content_types = ::Asset.content_associations

        ::Asset.instance_eval {
          content_types.each do |assoc, type|
            scope assoc, where(:content_type => type)
          end
        }
      end
    end

    module ActiveRecordMethods
      def acts_as_asset
        include AssetMethods
      end

      def acts_as_content
        include ContentMethods
      end
    end

    module AssetMethods
      extend ActiveSupport::Concern

      module ClassMethods
        def content_models
          superclass.direct_descendants.select {|m| m.included_modules.include?(ContentMethods)}
        end

        # {:discusstion => Discussion, :poll => Poll}
        def content_types
          content_models.inject({}) {|h, klass| h.update(
            klass.name.underscore.intern => klass)}
        end

        # {:discusstions => 'Discussion', :polls => 'Poll'}
        def content_associations
          content_types.inject ({}) {|h, (key, klass)| h.update(
            key.to_s.pluralize.intern => klass.name)}
        end
      end
    end # AssetMethods

    module ContentMethods
      extend ActiveSupport::Concern

      def title_with_prefix
        if self.persisted?
          I18n.t(:prefix, :scope => [:content, :title]) + self.title
        else
          I18n.t(:prefix, :scope => [:content, :title]) + I18n.t("#{self.class.name.pluralize.downcase}.new", :scope => [:content, :title, :subtitles])
        end
      end

      included do
        attr_accessible :title, :description, :industry_id, :image, :image_cache, :asset_attributes, :image_binary, :sub_head
        attr_accessor :image_binary

        has_one :asset, :as => :content, :dependent => :destroy

        validates :asset, :presence => true
        accepts_nested_attributes_for :asset

        mount_uploader :image, ImageUploader

        Delegations.each {|method| delegate method, :to => :asset}

        scope :containing_keywords, lambda {|keywords|
          clause = keywords.map do |k|
            where("assets.title LIKE :keyword OR assets.description LIKE :keyword", :keyword => "%#{k}%").arel.where_clauses
          end.join(" OR ")

          joins(:asset).where(clause)
        }

        scope :containing_phrase, lambda {|phrase|
          where("assets.title LIKE :phrase OR assets.description LIKE :phrase", :phrase => "%#{phrase}%")
        }

        scope :in_industry, lambda {|industry|
          joins(:asset).where('assets.industry_id' => industry)
        }

        scope :order_by_comment, lambda {
           joins(:asset)
          .joins('LEFT JOIN (SELECT c.commentable_id,
                                    MAX(c.created_at) AS created_at
                               FROM comments c
                           GROUP BY c.commentable_id) AS last_comment
                         ON last_comment.commentable_id = assets.id')
          .order("last_comment.created_at DESC")
        }

        scope :order_by_date,    joins(:asset).order("assets.created_at DESC")
        scope :order_by_hottest, joins(:asset).order("assets.comments_count DESC")
        scope :for_last_week, joins(:asset).where(:created_at => 7.day.ago.beginning_of_day..Date.today.beginning_of_day).order("created_at DESC")
      end

      # InstanceMethods :-)
      Delegations = [
        :company, :company=, :comments, :comments_count,
        :archived, :archived=, :archived?, :toggle_archived,
        :industry, :industry=, :industry_id, :industry_id=,

        :image, :image=, :image?, :image_changed?, :image_url, :image_will_change!, :image_cache, :image_cache=, :image_binary,

        :permalink, :to_param, :comments_count,
        :title, :description, :title=, :description=,

        :can_be_edited_by?, :can_be_deleted_by?,

        :last_comment_at
      ]

      module ClassMethods
        def new(attributes = {})
          ::Asset.new.tap do |asset|
            content = super()

            content.asset = asset
            asset.content = content

            content.attributes = attributes
          end.content
        end
      end
    end # ContentMethods
  end
end
