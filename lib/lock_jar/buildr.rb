# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements. See the NOTICE file distributed with this
# work for additional information regarding copyright ownership. The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require 'lock_jar'
require 'lock_jar/dsl'

module Buildr
  
  attr_reader :global_lockjar_dsl
  
  def lock_jar( &blk )
    @global_lockjar_dsl = ::LockJar::Dsl.evaluate(&blk)            
  end
  
  namespace "lock_jar" do
    desc "Lock dependencies for each project"    
    task("lock") do 
      projects.each do |project|      
        ::LockJar.lock( project.lockjar_dsl, "#{project.name}.lock" )
      end
    end
  end
  
  module LockJar
    module ProjectExtension
      include Extension
    
      class << self
        def lock_jar( &blk )
            @lockjar_dsl = LockJar::DSL.evaluate(&blk)    
            if Buildr.global_lockjar_dsl
              @lockjar_dsl.merge( Buildr.global_lockjar_dsl )
            end        
        end
      end
      
      def lockjar_dsl
        @lockjar_dsl || global_lockjar_dsl
      end
      
      after_define do |project|      
        task :compile => 'lock_jar:compile'
        task 'test:compile' => 'lock_jar:test:compile'
        
        namespace "lock_jar" do
            desc "Lock dependencies to JarFile"
            task("lock") do 
              dsl = project.lockjar_dsl
              if dsl
                ::LockJar.lock( dsl, :jarfile => "#{project.name}.lock" )
              else
                # XXX: output that there were not dependencies to lock
                puts "No lock_jar dependencies to lock for #{project.name}" 
              end              
            end      
            
            task("compile") do
              unless File.exists? "#{project.name}.lock"
                raise "#{project.name}.lock does not exist, run #{project.name}:lockjar:lock first"
              end
              jars = ::LockJar.list( "#{project.name}.lock", ['compile', 'runtime'] )
              project.compile.with( jars )
            end
            
            task("test:compile") do
              unless File.exists? "#{project.name}.lock"
                raise "#{project.name}.lock does not exist, run #{project.name}:lockjar:lock first"
              end
              jars = ::LockJar.list( "#{project.name}.lock", ['compile', 'test', 'runtime'] )
              
              project.test.compile.with( jars )
              project.test.with( jars )
            end
        end
      end
    end
  end
end

class Buildr::Project
  include Buildr::LockJar::ProjectExtension
end