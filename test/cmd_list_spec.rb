# coding: utf-8
require_relative 'spec_helper.rb'
require_relative 'data/releases_info.rb'

describe "crew list" do
  before(:all) do
    ndk_init
  end

  before(:each) do
    clean_hold
    clean_cache
    repository_init
    repository_clone
  end

  context "when given bad arguments" do

    context "with 3 incorrect arguments" do
      it "outputs error message" do
        crew 'list', 'a', 'b', 'c'
        expect(exitstatus).to_not be_zero
        expect(err.chomp).to eq('error: this command requires either one or no arguments')
        expect(out).to eq('')
      end
    end

    context "with 2 incorrect arguments" do
      it "outputs error message" do
        crew 'list', 'a', 'b'
        expect(exitstatus).to_not be_zero
        expect(err.chomp).to eq('error: this command requires either one or no arguments')
        expect(out).to eq('')
      end
    end

    context "with 2 correct arguments" do
      it "outputs error message" do
        crew 'list', 'utils', 'libs'
        expect(exitstatus).to_not be_zero
        expect(err.chomp).to eq('error: this command requires either one or no arguments')
        expect(out).to eq('')
      end
    end

    context "with incorrect argument" do
      it "outputs error message" do
        crew 'list', 'a'
        expect(exitstatus).to_not be_zero
        expect(err.chomp).to eq('error: argument must either \'packages\' or \'utils\'')
        expect(out).to eq('')
      end
    end
  end

  context "with libs argument" do

    context "no formulas and empty hold" do
      it "outputs nothing" do
        crew 'list', 'packages'
        expect(result).to eq(:ok)
        expect(out).to eq('')
      end
    end

    context "empty hold, one formula with one release" do
      it "outputs info about one not installed release" do
        copy_formulas 'libone.rb'
        crew 'list', 'packages'
        expect(result).to eq(:ok)
        expect(out.split("\n")).to eq(["   libone  1.0.0  1"])
      end
    end

    context "empty hold, one formula with three releases" do
      it "outputs info about three not installed releases" do
        copy_formulas 'libthree.rb'
        crew 'list', 'packages'
        expect(result).to eq(:ok)
        expect(out.split("\n")).to eq(["   libthree  1.1.1  1",
                                       "   libthree  2.2.2  1",
                                       "   libthree  3.3.3  1"])
      end
    end

    context "empty hold, three formulas with one, two and three releases" do
      it "outputs info about all available releases" do
        copy_formulas 'libone.rb', 'libtwo.rb', 'libthree.rb'
        crew 'list', 'packages'
        expect(result).to eq(:ok)
        expect(out.split("\n")).to eq(["   libone    1.0.0  1",
                                       "   libthree  1.1.1  1",
                                       "   libthree  2.2.2  1",
                                       "   libthree  3.3.3  1",
                                       "   libtwo    1.1.0  1",
                                       "   libtwo    2.2.0  1"])
      end
    end

    context "one formula with one release installed" do
      it "outputs info about one existing release and marks it as installed" do
        copy_formulas 'libone.rb'
        crew_checked 'install', 'libone'
        crew 'list', 'packages'
        expect(result).to eq(:ok)
        expect(out.split("\n")).to eq([" * libone  1.0.0  1"])
      end
    end

    context "one formula with 4 releases and one release installed" do
      it "outputs info about 4 releases and marks one as installed" do
        copy_formulas 'libfour.rb'
        crew_checked 'install', 'libfour:4.4.4'
        crew 'list', 'packages'
        expect(result).to eq(:ok)
        expect(out.split("\n")).to eq(["   libfour  1.1.1  1",
                                       "   libfour  2.2.2  2",
                                       "   libfour  3.3.3  3",
                                       " * libfour  4.4.4  4"])
      end
    end

    context "three formulas with one, two and three releases, one of each releases installed" do
      it "outputs info about six releases and marks three as installed" do
        copy_formulas 'libone.rb', 'libtwo.rb', 'libthree.rb'
        crew_checked 'install', 'libone', 'libtwo:1.1.0', 'libthree:1.1.1'
        crew 'list', 'packages'
        expect(result).to eq(:ok)
        expect(out.split("\n")).to eq([" * libone    1.0.0  1",
                                       " * libthree  1.1.1  1",
                                       "   libthree  2.2.2  1",
                                       "   libthree  3.3.3  1",
                                       " * libtwo    1.1.0  1",
                                       "   libtwo    2.2.0  1"])
      end
    end

    context "four formulas with many releases, latest release of each formula installed" do
      it "outputs info about existing and installed releases" do
        copy_formulas 'libone.rb', 'libtwo.rb', 'libthree.rb', 'libfour.rb'
        crew_checked 'install', 'libone', 'libtwo', 'libthree', 'libfour'
        crew 'list', 'packages'
        expect(result).to eq(:ok)
        expect(out.split("\n")).to eq(["   libfour   1.1.1  1",
                                       "   libfour   2.2.2  2",
                                       "   libfour   3.3.3  3",
                                       " * libfour   4.4.4  4",
                                       " * libone    1.0.0  1",
                                       "   libthree  1.1.1  1",
                                       "   libthree  2.2.2  1",
                                       " * libthree  3.3.3  1",
                                       "   libtwo    1.1.0  1",
                                       " * libtwo    2.2.0  1"])
      end
    end
  end

  context "with utils argument" do

    context "when there is one release of every utility" do
      it "outputs info about installed utilities" do
        crew 'list', 'utils'
        expect(result).to eq(:ok)
        bv  = Crew_test::UTILS_RELEASES['libarchive'][0].version
        bcv = Crew_test::UTILS_RELEASES['libarchive'][0].crystax_version
        cv  = Crew_test::UTILS_RELEASES['curl'][0].version
        ccv = Crew_test::UTILS_RELEASES['curl'][0].crystax_version
        rv  = Crew_test::UTILS_RELEASES['ruby'][0].version
        rcv = Crew_test::UTILS_RELEASES['ruby'][0].crystax_version
        expect(out).to match(/ \* bsdtar\s+#{bv}\s+#{bcv}\R \* curl  \s+#{cv}\s+#{ccv}\R \* ruby  \s+#{rv}\s+#{rcv}\R/)
      end
    end

    # todo:
    # context "when more than one release of one utility installed" do
    # end
  end

  context "whithout arguments" do

    context "when some formulas are with many releases, and there is one release of every utility" do
      it "outputs info about existing and installed releases" do
        copy_formulas 'libone.rb', 'libtwo.rb', 'libthree.rb', 'libfour.rb'
        crew_checked 'install', 'libone', 'libtwo', 'libthree', 'libfour'
        crew 'list'
        expect(result).to eq(:ok)
        got = out.split("\n")
        exp = ["Packages:",
               "   libfour   1.1.1  1",
               "   libfour   2.2.2  2",
               "   libfour   3.3.3  3",
               " * libfour   4.4.4  4",
               " * libone    1.0.0  1",
               "   libthree  1.1.1  1",
               "   libthree  2.2.2  1",
               " * libthree  3.3.3  1",
               "   libtwo    1.1.0  1",
               " * libtwo    2.2.0  1",
               "Utilities:",
               / \* bsdtar\s+#{Crew_test::UTILS_RELEASES['libarchive'][0].version}\s+#{Crew_test::UTILS_RELEASES['libarchive'][0].crystax_version}/,
               / \* curl  \s+#{Crew_test::UTILS_RELEASES['curl'][0].version}\s+#{Crew_test::UTILS_RELEASES['curl'][0].crystax_version}/,
               / \* ruby  \s+#{Crew_test::UTILS_RELEASES['ruby'][0].version}\s+#{Crew_test::UTILS_RELEASES['ruby'][0].crystax_version}/]
        expect(got.size).to eq(exp.size)
        got.each_with_index { |g, i| expect(g).to match(exp[i]) }
      end
    end
  end
end
