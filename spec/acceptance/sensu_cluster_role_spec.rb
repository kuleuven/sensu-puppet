require 'spec_helper_acceptance'

describe 'sensu_cluster_role', if: RSpec.configuration.sensu_full do
  node = hosts_as('sensu_backend')[0]
  context 'default' do
    it 'should work without errors' do
      pp = <<-EOS
      include ::sensu::backend
      sensu_cluster_role { 'test':
        rules => [{'verbs' => ['get','list'], 'resources' => ['checks']}],
      }
      EOS

      if RSpec.configuration.sensu_use_agent
        site_pp = "node 'sensu_backend' { #{pp} }"
        puppetserver = hosts_as('puppetserver')[0]
        create_remote_file(puppetserver, "/etc/puppetlabs/code/environments/production/manifests/site.pp", site_pp)
        on node, puppet("agent -t --detailed-exitcodes"), acceptable_exit_codes: [0,2]
        on node, puppet("agent -t --detailed-exitcodes"), acceptable_exit_codes: [0]
      else
        # Run it twice and test for idempotency
        apply_manifest_on(node, pp, :catch_failures => true)
        apply_manifest_on(node, pp, :catch_changes  => true)
      end
    end

    it 'should have a valid cluster_role' do
      on node, 'sensuctl cluster-role info test --format json' do
        data = JSON.parse(stdout)
        expect(data['rules']).to eq([{'verbs' => ['get','list'], 'resources' => ['checks'], 'resource_names' => nil}])
      end
    end
  end

  context 'update cluster_role' do
    it 'should work without errors' do
      pp = <<-EOS
      include ::sensu::backend
      sensu_cluster_role { 'test':
        rules => [
          {'verbs' => ['get','list'], 'resources' => ['*'], resource_names => ['foo']},
          {'verbs' => ['get','list'], 'resources' => ['checks'], resource_names => ['bar']},
        ],
      }
      EOS

      if RSpec.configuration.sensu_use_agent
        site_pp = "node 'sensu_backend' { #{pp} }"
        puppetserver = hosts_as('puppetserver')[0]
        create_remote_file(puppetserver, "/etc/puppetlabs/code/environments/production/manifests/site.pp", site_pp)
        on node, puppet("agent -t --detailed-exitcodes"), acceptable_exit_codes: [0,2]
        on node, puppet("agent -t --detailed-exitcodes"), acceptable_exit_codes: [0]
      else
        # Run it twice and test for idempotency
        apply_manifest_on(node, pp, :catch_failures => true)
        apply_manifest_on(node, pp, :catch_changes  => true)
      end
    end

    it 'should have a valid cluster_role with updated propery' do
      on node, 'sensuctl cluster-role info test --format json' do
        data = JSON.parse(stdout)
        expect(data['rules'].size).to eq(2)
        expect(data['rules'][0]).to eq({'verbs' => ['get','list'], 'resources' => ['*'], 'resource_names' => ['foo']})
        expect(data['rules'][1]).to eq({'verbs' => ['get','list'], 'resources' => ['checks'], 'resource_names' => ['bar']})
      end
    end
  end

  context 'ensure => absent' do
    it 'should remove without errors' do
      pp = <<-EOS
      include ::sensu::backend
      sensu_cluster_role { 'test': ensure => 'absent' }
      EOS

      if RSpec.configuration.sensu_use_agent
        site_pp = "node 'sensu_backend' { #{pp} }"
        puppetserver = hosts_as('puppetserver')[0]
        create_remote_file(puppetserver, "/etc/puppetlabs/code/environments/production/manifests/site.pp", site_pp)
        on node, puppet("agent -t --detailed-exitcodes"), acceptable_exit_codes: [0,2]
        on node, puppet("agent -t --detailed-exitcodes"), acceptable_exit_codes: [0]
      else
        # Run it twice and test for idempotency
        apply_manifest_on(node, pp, :catch_failures => true)
        apply_manifest_on(node, pp, :catch_changes  => true)
      end
    end

    describe command('sensuctl cluster-role info test'), :node => node do
      its(:exit_status) { should_not eq 0 }
    end
  end

  context 'resource purging' do
    it 'should purge without errors' do
      before_pp = <<-EOS
      include ::sensu::backend
      sensu_cluster_role { 'test1':
        rules => [{'verbs' => ['get','list'], 'resources' => ['checks']}],
      }
      EOS
      pp = <<-EOS
      sensu_resources { 'sensu_cluster_role':
        purge => true
      }
      include ::sensu::backend
      sensu_cluster_role { 'test2':
        rules => [{'verbs' => ['get','list'], 'resources' => ['checks']}],
      }
      EOS

      apply_manifest_on(node, before_pp, :catch_failures => true)
      if RSpec.configuration.sensu_use_agent
        site_pp = "node 'sensu_backend' { #{pp} }"
        puppetserver = hosts_as('puppetserver')[0]
        create_remote_file(puppetserver, "/etc/puppetlabs/code/environments/production/manifests/site.pp", site_pp)
        on node, puppet("agent -t --detailed-exitcodes"), acceptable_exit_codes: [0,2]
        on node, puppet("agent -t --detailed-exitcodes"), acceptable_exit_codes: [0]
      else
        # Run it twice and test for idempotency
        apply_manifest_on(node, pp, :catch_failures => true)
        apply_manifest_on(node, pp, :catch_changes  => true)
      end
    end

    describe command('sensuctl cluster-role info test1'), :node => node do
      its(:exit_status) { should_not eq 0 }
    end
    describe command('sensuctl cluster-role info test2'), :node => node do
      its(:exit_status) { should eq 0 }
    end
  end
end

